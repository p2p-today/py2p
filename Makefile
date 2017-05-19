#Python setup section

#This help message was taken from https://gist.github.com/rcmachado/af3db315e31383502660
## Show this help.
help:
	@printf "Available targets\n\n"
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "%-20s %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

pip = -m pip install
py_deps = $(pip) cryptography --upgrade
py_test_deps = $(pip) pytest-coverage pytest-benchmark pytest-ordering
docs_deps = $(pip) sphinx sphinxcontrib-napoleon sphinx_rtd_theme

ifeq ($(shell python -c 'import sys; print(int(hasattr(sys, "real_prefix")))'), 0) # check for virtualenv
	py_deps += --user
	py_test_deps += --user
	docs_deps += --user
	user_postfix = --user
else
	user_postfix =
endif

ifeq ($(shell python -c 'import sys; print((sys.version_info[0]))'), 3)
	python2 = python2
	python3 = python
else
	python2 = python
	python3 = python3
endif

ifeq ($(shell python -c "import sys; print(hasattr(sys, 'pypy_version_info'))"), True)
	pypy = True
	ifeq ($(python2), python)
		python2 = python2
	endif
else
	pypy = False
endif

pylibdir = $(shell python -c "import sys, sysconfig; print('lib.{}-{v[0]}.{v[1]}'.format(sysconfig.get_platform(), v=sys.version_info))")
py2libdir = $(shell $(python2) -c "import sys, sysconfig; print('lib.{}-{v[0]}.{v[1]}'.format(sysconfig.get_platform(), v=sys.version_info))")
py3libdir = $(shell $(python3) -c "import sys, sysconfig; print('lib.{}-{v[0]}.{v[1]}'.format(sysconfig.get_platform(), v=sys.version_info))")
ifeq ($(python2), python)
	pyunvlibdir = $(pylibdir)
else
	pyunvlibdir = lib
endif

## Initialize submodules
submodules:
	@git submodule update --init --recursive

## Build python-only code for whatever your default system python is
python: LICENSE setup.py
	@echo "Checking dependencies..."
	@python $(py_deps) --upgrade
	@python $(pip) -r requirements.txt --upgrade $(user_postfix)
	@echo "Building python-only version..."
	@python setup.py build --universal

## Build python-only code for whatever your system python3 version is
python3: LICENSE setup.py
	@echo "Checking dependencies..."
	@$(python3) $(py_deps) --upgrade
	@$(python3) $(pip) -r requirements.txt --upgrade $(user_postfix)
	@echo "Building python-only version..."
	@$(python3) setup.py build --universal

## Build python-only code for whatever your system python2 version is
python2: LICENSE setup.py
	@echo "Checking dependencies..."
	@$(python2) $(py_deps) --upgrade
	@$(python2) $(pip) -r requirements.txt --upgrade $(user_postfix)
	@echo "Building python-only version..."
	@$(python2) setup.py build --universal

ifeq ($(pypy), True)
## Build python-only code for whatever your system pypy version is
pypy: LICENSE setup.py
	@echo "Checking dependencies..."
	@pypy $(py_deps) --upgrade
	@pypy $(pip) -r requirements.txt --upgrade $(user_postfix)
	@echo "Building python-only version..."
	@pypy setup.py build --universal
else
pypy:
	@echo "You do not have pypy installed"
endif

ifeq ($(pypy), True)
cpython: python

else
## Build binary and python code for whatever your default system python is (python-only if that's pypy)
cpython: python submodules
	@echo "Building with C extensions..."
ifeq ($(debug), true)
	@python setup.py build --debug
else
	@python setup.py build
endif
endif

## Build binary and python code for whatever your system python3 version is
cpython3: python3 submodules
	@echo "Building with C extensions..."
ifeq ($(debug), true)
	@$(python3) setup.py build --debug
else
	@$(python3) setup.py build
endif

## Build binary and python code for whatever your system python2 version is
cpython2: python2 submodules
	@echo "Building with C extensions..."
ifeq ($(debug), true)
	@$(python2) setup.py build --debug
else
	@$(python2) setup.py build
endif

## Install python test dependencies
pytestdeps:
	@echo "Checking test dependencies..."
	@python $(py_test_deps) --upgrade

## Install python2 test dependencies
py2testdeps:
	@echo "Checking test dependencies..."
	@$(python2) $(py_test_deps) --upgrade

## Install python3 test dependencies
py3testdeps:
	@echo "Checking test dependencies..."
	@$(python3) $(py_test_deps) --upgrade

## Run python tests
pytest: LICENSE setup.py setup.cfg python pytestdeps
ifeq ($(cov), true)
	@python -m pytest -c ./setup.cfg --cov=build/$(pyunvlibdir) build/$(pyunvlibdir)
else
	@python -m pytest -c ./setup.cfg build/$(pyunvlibdir)
endif

## Run python2 tests
py2test: LICENSE setup.py setup.cfg python2 py2testdeps
ifeq ($(cov), true)
	@$(python2) -m pytest -c ./setup.cfg --cov=build/$(py2libdir) build/$(py2libdir)
else
	@$(python2) -m pytest -c ./setup.cfg build/$(py2libdir)
endif

## Run python3 tests
py3test: LICENSE setup.py setup.cfg python3 py3testdeps
	@echo $(py3libdir)
ifeq ($(cov), true)
	@$(python3) -m pytest -c ./setup.cfg --cov=build/lib build/lib
else
	@$(python3) -m pytest -c ./setup.cfg build/lib
endif

ifeq ($(pypy), True)
cpytest: pytest

else
## Run cpython tests
cpytest: LICENSE setup.py setup.cfg cpython pytestdeps
ifeq ($(cov), true)
	@python -m pytest -c ./setup.cfg --cov=build/$(pylibdir) build/$(pylibdir)
else
	@python -m pytest -c ./setup.cfg build/$(pylibdir)
endif
endif

## Run cpython2 tests
cpy2test: LICENSE setup.py setup.cfg cpython2 py2testdeps
ifeq ($(cov), true)
	@$(python2) -m pytest -c ./setup.cfg --cov=build/$(py2libdir) build/$(py2libdir)
else
	@$(python2) -m pytest -c ./setup.cfg build/$(py2libdir)
endif

## Run cpython3 tests
cpy3test: LICENSE setup.py setup.cfg cpython3 py3testdeps
ifeq ($(cov), true)
	@$(python3) -m pytest -c ./setup.cfg --cov=build/$(py3libdir) build/$(py3libdir)
else
	@$(python3) -m pytest -c ./setup.cfg build/$(py3libdir)
endif

## Format the python code in place with YAPF
pyformat: clean
	@$(python3) -m pip install yapf --upgrade $(user_postfix)
	@$(python3) -m yapf py_src -ri
	@$(MAKE) mypy pytest

## Run mypy tests
mypy:
	@$(python3) -m pip install mypy --upgrade $(user_postfix)
	@$(python3) -m mypy . --check-untyped-defs --ignore-missing-imports --disallow-untyped-calls --disallow-untyped-defs

## Clean up local folders, including Javascript depenedencies
clean:
	@rm -rf .benchmarks .cache build coverage dist venv py_src/__pycache__ \
	py_src/test/__pycache__ py_src/*.pyc py_src/test/*.pyc py_src/*.so

## Run all python-related build recipes
all: LICENSE setup.py setup.cfg python2 python3 cpython2 cpython3 pypy
