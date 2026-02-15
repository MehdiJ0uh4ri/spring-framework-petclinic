#!/bin/bash
################################################################################
# Local Terraform Build & Deploy Script
# Purpose: Build Docker image locally and deploy with Terraform
# Usage: ./scripts/build-and-deploy-local.sh
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$PROJECT_ROOT/infrastructure"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"

################################################################################
# FUNCTIONS
################################################################################

log_section() {
  echo ""
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}════════════════════════════════════════${NC}"
}

log_step() {
  echo -e "${YELLOW}▶ $1${NC}"
}

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

check_command() {
  if ! command -v "$1" &> /dev/null; then
    log_error "$1 is not installed"
    echo "Please install $1 and try again"
    exit 1
  fi
}

################################################################################
# PRE-FLIGHT CHECKS
################################################################################

log_section "PRE-FLIGHT CHECKS"

log_step "Checking required commands..."
check_command docker
check_command terraform
check_command git
log_success "All required commands found"

log_step "Checking Docker daemon..."
if ! docker ps > /dev/null 2>&1; then
  log_error "Docker daemon is not running"
  echo "Starting Docker..."
  sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true
  sleep 2
  
  if ! docker ps > /dev/null 2>&1; then
    log_error "Failed to start Docker daemon"
    exit 1
  fi
fi
log_success "Docker daemon is running"

log_step "Checking project structure..."
if [ ! -f "$PROJECT_ROOT/Dockerfile" ]; then
  log_error "Dockerfile not found at $PROJECT_ROOT/Dockerfile"
  exit 1
fi

if [ ! -d "$INFRA_DIR" ]; then
  log_error "infrastructure directory not found at $INFRA_DIR"
  exit 1
fi
log_success "Project structure is valid"

################################################################################
# STEP 1: BUILD JAVA APPLICATION
################################################################################

log_section "STEP 1: BUILD JAVA APPLICATION"

log_step "Building Spring Boot application with Maven..."
cd "$PROJECT_ROOT"

if [ -f "mvnw" ]; then
  if ./mvnw clean package -DskipTests; then
    log_success "Maven build successful"
  else
    log_error "Maven build failed"
    exit 1
  fi
else
  log_error "mvnw not found"
  exit 1
fi

################################################################################
# STEP 2: BUILD DOCKER IMAGE
################################################################################

log_section "STEP 2: BUILD DOCKER IMAGE"

log_step "Building Docker image from Dockerfile..."
cd "$PROJECT_ROOT"

if docker build -t petclinic:local .; then
  log_success "Docker image built successfully"
else
  log_error "Docker build failed"
  exit 1
fi

log_step "Verifying image was created..."
if docker images | grep -q "petclinic.*local"; then
  IMAGE_ID=$(docker images | grep "petclinic.*local" | head -1 | awk '{print $3}')
  IMAGE_SIZE=$(docker images | grep "petclinic.*local" | head -1 | awk '{print $7}')
  log_success "Image verified: ID=$IMAGE_ID, Size=$IMAGE_SIZE"
else
  log_error "Image not found after build"
  exit 1
fi

################################################################################
# STEP 3: PREPARE TERRAFORM
################################################################################

log_section "STEP 3: PREPARE TERRAFORM"

log_step "Checking Terraform configuration..."
cd "$INFRA_DIR"

if [ ! -f "main.tf" ]; then
  log_error "main.tf not found in $INFRA_DIR"
  exit 1
fi

if [ ! -f "terraform.tfvars" ]; then
  log_error "terraform.tfvars not found in $INFRA_DIR"
  exit 1
fi

if [ ! -f "terraform.local.tfvars" ]; then
  log_error "terraform.local.tfvars not found in $INFRA_DIR"
  echo "Create it with: cp terraform.tfvars terraform.local.tfvars"
  echo "Then edit to set: build_image_locally = true"
  exit 1
fi

log_success "Terraform configuration files found"

log_step "Initializing Terraform..."
if terraform init; then
  log_success "Terraform initialized"
else
  log_error "Terraform init failed"
  exit 1
fi

################################################################################
# STEP 4: TERRAFORM PLAN
################################################################################

log_section "STEP 4: TERRAFORM PLAN"

log_step "Planning Terraform deployment..."

if terraform plan \
  -var-file="terraform.tfvars" \
  -var-file="terraform.local.tfvars" \
  -out=tfplan; then
  log_success "Terraform plan successful"
else
  log_error "Terraform plan failed"
  exit 1
fi

log_step "Terraform plan summary:"
terraform show tfplan | grep -E "Plan:|No changes|will be" || true

################################################################################
# STEP 5: USER CONFIRMATION
################################################################################

log_section "CONFIRMATION REQUIRED"

echo ""
echo "This will create the following Docker containers:"
echo "  • petclinic-mysql (MySQL 8.0)"
echo "  • petclinic-app (Spring PetClinic)"
echo "  • petclinic-network (Docker network)"
echo ""
echo "Ports:"
echo "  • Application: http://localhost:8080"
echo "  • MySQL: localhost:3306"
echo ""
read -p "Continue with deployment? (yes/no) " -r response

if [ "$response" != "yes" ]; then
  log_step "Deployment cancelled"
  exit 0
fi

################################################################################
# STEP 6: TERRAFORM APPLY
################################################################################

log_section "STEP 6: TERRAFORM APPLY"

log_step "Applying Terraform configuration..."

if terraform apply tfplan; then
  log_success "Terraform apply successful"
  rm -f tfplan  # Clean up plan file
else
  log_error "Terraform apply failed"
  exit 1
fi

################################################################################
# STEP 7: WAIT FOR APPLICATION
################################################################################

log_section "STEP 7: WAIT FOR APPLICATION"

log_step "Waiting for application to start (max 120 seconds)..."

max_attempts=120
attempt=0
app_ready=false

while [ $attempt -lt $max_attempts ]; do
  if curl -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
    app_ready=true
    break
  fi
  
  attempt=$((attempt + 1))
  if [ $((attempt % 10)) -eq 0 ]; then
    echo "  Still waiting... ($attempt/$max_attempts seconds)"
  fi
  sleep 1
done

if [ "$app_ready" = true ]; then
  log_success "Application is ready!"
else
  log_error "Application failed to start after $max_attempts seconds"
  echo ""
  echo "Checking application logs:"
  docker logs petclinic-app | tail -30 || true
  exit 1
fi

################################################################################
# STEP 8: SMOKE TESTS
################################################################################

log_section "STEP 8: SMOKE TESTS"

log_step "Running smoke tests..."

# Test 1: Root endpoint
log_step "Test 1: GET /"
if curl -f http://localhost:8080/ > /dev/null 2>&1; then
  log_success "Root endpoint responding"
else
  log_error "Root endpoint failed"
fi

# Test 2: Health check
log_step "Test 2: GET /actuator/health"
HEALTH=$(curl -s http://localhost:8080/actuator/health | grep -o '"status":"[^"]*"')
if [ ! -z "$HEALTH" ]; then
  log_success "Health check: $HEALTH"
else
  log_error "Health check failed"
fi

################################################################################
# STEP 9: DISPLAY RESULTS
################################################################################

log_section "DEPLOYMENT COMPLETE ✅"

echo ""
echo -e "${GREEN}Your application is now running!${NC}"
echo ""

APP_URL="http://localhost:8080"
MYSQL_HOST="petclinic"
MYSQL_PORT="3306"
MYSQL_USER="petclinic"
MYSQL_PASS="petclinic"

echo "📍 APPLICATION"
echo "   URL: $APP_URL"
echo ""

echo "🔌 DATABASE"
echo "   Host: $MYSQL_HOST"
echo "   Port: $MYSQL_PORT"
echo "   User: $MYSQL_USER"
echo "   Pass: $MYSQL_PASS"
echo ""

echo "🐳 DOCKER CONTAINERS"
docker ps --filter name=petclinic --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" || true
echo ""

echo "🛠️  USEFUL COMMANDS"
echo "   View app logs:      docker logs -f petclinic-app"
echo "   View MySQL logs:    docker logs -f petclinic"
echo "   List containers:    docker ps -a"
echo "   Stop containers:    terraform destroy -var-file=terraform.tfvars -var-file=terraform.local.tfvars"
echo ""

echo "📝 CONNECTION INFO"
echo "   Saved to: $INFRA_DIR/connection-info.json"
if [ -f "$INFRA_DIR/connection-info.json" ]; then
  cat "$INFRA_DIR/connection-info.json" | python3 -m json.tool 2>/dev/null || cat "$INFRA_DIR/connection-info.json"
fi
echo ""

echo "📚 NEXT STEPS"
echo "   1. Test your application at $APP_URL"
echo "   2. Run some API calls or UI tests"
echo "   3. Check logs if something breaks"
echo "   4. When done: terraform destroy"
echo ""

log_success "Local deployment complete!"