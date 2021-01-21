#!/bin/bash -e

DIR_TEMPLATE_NAME="__bricksflow__"
PROJECT_TEMPLATE_NAME="__myproject__"

resolve_arguments() {
  if [ -z ${1+x} ]; then
    echo "Usage ./create_project.sh PROJECT_TEMPLATE_URL|BRICKSFLOW_REPO_NAME [PROJECT_NAME] [ROOT_MODULE_NAME]"
    return 1
  elif [[ "$1" == "https://"* ]]; then
    TEMPLATE_URL="$1"
  else
    TEMPLATE_URL="https://github.com/bricksflow/$1/archive/master.zip"
  fi

  if [ -z ${2+x} ]; then
    read -p "Enter your project name [testproject]: " PROJECT_NAME </dev/tty
    PROJECT_NAME="${PROJECT_NAME:-testproject}"
  else
    PROJECT_NAME="$2"
    echo "Using project name: $PROJECT_NAME"
  fi

  if [ -z ${3+x} ]; then
    read -p "Enter the root module name [$PROJECT_NAME]: " ROOT_MODULE_NAME </dev/tty
    ROOT_MODULE_NAME="${ROOT_MODULE_NAME:-$PROJECT_NAME}"
  else
    ROOT_MODULE_NAME="$3"
    echo "Using root module name: $ROOT_MODULE_NAME"
  fi
}

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
    return 1
  fi
}

download_repo() {
  local TEMPLATE_URL="$1"
  echo "Preparing project template..."

  local EXTENSION="${TEMPLATE_URL##*.}"

  if [[ "$TEMPLATE_URL" == "https://dev.azure.com/"* ]]; then
    local TMP_DIR=$(mktemp -d)
    local TEMPLATE_FILENAME="bricksflow-template.zip"
    local TEMPLATE_FILE_NO_EXT="${TEMPLATE_FILENAME%.*}"

    echo "Downloading project template from: $TEMPLATE_URL"
    curl -u :$PAT_TOKEN "$TEMPLATE_URL" --silent -o "$TMP_DIR/$TEMPLATE_FILENAME"

    echo "Unziping $TMP_DIR/$TEMPLATE_FILENAME into $TMP_DIR/$TEMPLATE_FILE_NO_EXT"

    unzip -qq "$TMP_DIR/$TEMPLATE_FILENAME" -d "$TMP_DIR/$TEMPLATE_FILE_NO_EXT"
    rm -f "$TMP_DIR/$TEMPLATE_FILENAME"

    EXTRACT_DIR="$TMP_DIR/$TEMPLATE_FILE_NO_EXT"
    PYCHARM_CONFIG_DIR="$EXTRACT_DIR/.idea"
  elif [ "$EXTENSION" != "zip" ]; then
    echo "Project template must be in zip format"
    return 1
  else
    local TMP_DIR=$(mktemp -d)
    local TEMPLATE_FILENAME="$(basename -- $TEMPLATE_URL)"

    echo "Downloading project template from: $TEMPLATE_URL"
    curl -sSL "$TEMPLATE_URL" --silent -o "$TMP_DIR/$TEMPLATE_FILENAME"

    echo "Unziping $TMP_DIR/$TEMPLATE_FILENAME into $TMP_DIR"

    unzip -qq "$TMP_DIR/$TEMPLATE_FILENAME" -d "$TMP_DIR"
    rm -f "$TMP_DIR/$TEMPLATE_FILENAME"

    local TEMPLATE_FILE_NO_EXT="${TEMPLATE_FILENAME%.*}"

    EXTRACT_DIR="$TMP_DIR/bricksflow-$TEMPLATE_FILE_NO_EXT"
    PYCHARM_CONFIG_DIR="$EXTRACT_DIR/.idea"
  fi
}

rename_package_name() {
  local EXTRACT_DIR="$1"
  local SEARCH="$2"
  local REPLACE="$3"

  mv "$EXTRACT_DIR/src/$SEARCH" "$EXTRACT_DIR/src/$REPLACE"
}

update_pycharm_configs() {
  local EXTRACT_DIR="$1"
  local SEARCH="$2"
  local REPLACE="$3"

  local PYCHARM_CONFIG_DIR="$EXTRACT_DIR/.idea"

  mv "$PYCHARM_CONFIG_DIR/$SEARCH.iml" "$PYCHARM_CONFIG_DIR/$REPLACE.iml"
  rm -f "$PYCHARM_CONFIG_DIR/vcs.xml"
}

finalize() {
  mkdir -p "$PROJECT_DIR"

  mv "$EXTRACT_DIR/"* "$PROJECT_DIR"
  mv "$EXTRACT_DIR/".[!.]* "$PROJECT_DIR"

  (cd "$PROJECT_DIR" && chmod +x ./env-init.sh && ./env-init.sh -y)
}

create_project_from_template() {
  perl -i -pe "s/t${PROJECT_TEMPLATE_NAME}t/$PROJECT_NAME/g" "$EXTRACT_DIR/pyproject.toml"
  rm -f "$EXTRACT_DIR/pyproject.toml.bak"

  replace_string_in_dir "$EXTRACT_DIR" "$PROJECT_TEMPLATE_NAME" "$PROJECT_NAME"
  rename_package_name "$EXTRACT_DIR" "$PROJECT_TEMPLATE_NAME" "$PROJECT_NAME"

  replace_string_in_dir "$EXTRACT_DIR" "$DIR_TEMPLATE_NAME" "$PROJECT_NAME"
  update_pycharm_configs "$EXTRACT_DIR" "$DIR_TEMPLATE_NAME" "$PROJECT_NAME"

  finalize
}

if resolve_arguments "$@"; then
  PROJECT_DIR="$PWD/$ROOT_MODULE_NAME"

  if initial_checks; then
    if download_repo "$TEMPLATE_URL" "$PAT_TOKEN"; then
      create_project_from_template
    fi
  fi
fi