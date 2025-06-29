

if [[ -n "$CREATE_TEST_GIT" ]] ; then
    echo "Creating test git directory at $CREATE_TEST_GIT"
    sudo mkdir -p $CREATE_TEST_GIT
    sudo chown $(whoami) $CREATE_TEST_GIT
    cd $CREATE_TEST_GIT
    git init
    echo Creating pre-commit hook directory ${HOOKSDIR:-"git/hooks"}/pre-commit.d
    mkdir -p ${HOOKSDIR:-"git/hooks"}/pre-commit.d
fi
