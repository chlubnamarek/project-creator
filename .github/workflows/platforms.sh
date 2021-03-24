run_tests() {
  local DAIPE_TEMPLATE_URL=https://github.com/daipe-ai/skeleton-databricks/archive/master.zip
  curl -s https://raw.githubusercontent.com/chlubnamarek/project-creator/${GITHUB_REF:11}/create_project.sh | bash -s $DAIPE_TEMPLATE_URL myproject mydir
  cd mydir

  sed -i.bak 's/DBX_TOKEN=/DBX_TOKEN=abcdefgh123456789/g' .env # set DBX_TOKEN to non-empty value

  eval "$(conda shell.bash hook)"
  conda activate "$PWD/.venv"
  black --check src
  python src/myproject/ContainerTest.py
}
