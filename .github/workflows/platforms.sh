run_tests() {
  curl -s https://raw.githubusercontent.com/bricksflow/project-creator/${GITHUB_REF:11}/create_project.sh | bash -s myproject mydir
  cd mydir

  sed -i.bak 's/DBX_TOKEN=/DBX_TOKEN=abcdefgh123456789/g' .env # set DBX_TOKEN to non-empty value

  eval "$(conda shell.bash hook)"
  conda activate "$PWD/.venv"
  ./run_tests.sh
  ./pylint.sh
}
