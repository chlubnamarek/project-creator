#!/bin/bash -e

DIR_TEMPLATE_NAME="__bricksflow__"
PROJECT_TEMPLATE_NAME="__myproject__"

if [[ -z "$BRICKSFLOW_BRANCH" ]]; then BRICKSFLOW_BRANCH="master"; fi
if [[ -z "$ENV_INIT_BRANCH" ]]; then ENV_INIT_BRANCH="master"; fi

replace_string_in_file() {
  local FILE_PATH="$1"
  local SEARCH="$2"
  local REPLACE="$3"

  perl -i -pe "s/$SEARCH/$REPLACE/g" "$FILE_PATH"
  rm -f "$FILE_PATH.bak"
}

replace_string_in_dir() {
  local DIR_PATH="$1"
  local SEARCH="$2"
  local REPLACE="$3"

  grep "$SEARCH" "$DIR_PATH" -Rl | while IFS= read -r FILE_PATH; do
    replace_string_in_file "$FILE_PATH" "$SEARCH" "$REPLACE"
  done
}

initial_checks() {
  if [ -d "$PROJECT_DIR" ]; then
    echo "$PROJECT_DIR already exists, cancelling"
    exit 1
  fi
}

download_repo() {
  echo "Preparing project template..."

  local TMP_DIR=$(mktemp -d)

  echo "Downloading project template from: $BRICKSFLOW_BRANCH"
  curl -sSL "https://github.com/bricksflow/bricksflow/archive/$BRICKSFLOW_BRANCH.zip" --silent -o "$TMP_DIR/$BRICKSFLOW_BRANCH.zip"

  echo "Unziping"
  unzip -qq "$TMP_DIR/$BRICKSFLOW_BRANCH.zip" -d "$TMP_DIR"
  rm -f "$TMP_DIR/$BRICKSFLOW_BRANCH.zip"
  MASTER_DIR="$TMP_DIR/bricksflow-$BRICKSFLOW_BRANCH"
  PYCHARM_CONFIG_DIR="$MASTER_DIR/.idea"
}

rename_package_name() {
  local MASTER_DIR="$1"
  local SEARCH="$2"
  local REPLACE="$3"

  mv "$MASTER_DIR/src/$SEARCH" "$MASTER_DIR/src/$REPLACE"
}

update_pycharm_configs() {
  local MASTER_DIR="$1"
  local SEARCH="$2"
  local REPLACE="$3"

  local PYCHARM_CONFIG_DIR="$MASTER_DIR/.idea"

  mv "$PYCHARM_CONFIG_DIR/$SEARCH.iml" "$PYCHARM_CONFIG_DIR/$REPLACE.iml"
  rm -f "$PYCHARM_CONFIG_DIR/vcs.xml"
}

finalize() {
  mkdir -p "$PROJECT_DIR"

  mv "$MASTER_DIR/"* "$PROJECT_DIR"
  mv "$MASTER_DIR/".[!.]* "$PROJECT_DIR"

  (cd "$PROJECT_DIR" && ENV_INIT_BRANCH=$ENV_INIT_BRANCH ./env-init.sh -y)
}

if [ -z ${1+x} ]; then
  read -p "Enter your project name [testproject]: " PROJECT_NAME
  PROJECT_NAME="${PROJECT_NAME:-testproject}"
else
  PROJECT_NAME="$1"
fi

if [ -z ${2+x} ]; then
  read -p "Enter the root module name [$PROJECT_NAME]: " ROOT_MODULE_NAME
  ROOT_MODULE_NAME="${ROOT_MODULE_NAME:-$PROJECT_NAME}"
else
  ROOT_MODULE_NAME="$2"
fi

PROJECT_DIR="$PWD/$ROOT_MODULE_NAME"

initial_checks
download_repo

perl -i -pe "s/t${PROJECT_TEMPLATE_NAME}t/$PROJECT_NAME/g" "$MASTER_DIR/pyproject.toml"
rm -f "$MASTER_DIR/pyproject.toml.bak"

replace_string_in_dir "$MASTER_DIR" "$PROJECT_TEMPLATE_NAME" "$PROJECT_NAME"
rename_package_name "$MASTER_DIR" "$PROJECT_TEMPLATE_NAME" "$PROJECT_NAME"

replace_string_in_dir "$MASTER_DIR" "$DIR_TEMPLATE_NAME" "$PROJECT_NAME"
update_pycharm_configs "$MASTER_DIR" "$DIR_TEMPLATE_NAME" "$PROJECT_NAME"

finalize
