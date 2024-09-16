import sys
import os
import subprocess
import time

ROOT_PATH = os.path.realpath(os.path.join(os.path.dirname(__file__), ".."))
TMP_DIR = os.path.join(ROOT_PATH, "test", "tmp")
BOOK_REPO_PATH = os.path.join(TMP_DIR, "craftinginterpreters")
RELATIVE_JLOX_PATH = "../../../plox/plox"
RELATIVE_CLOX_PATH = "../../../dlox/dlox"

os.makedirs(TMP_DIR, exist_ok=True)
if not os.path.exists(BOOK_REPO_PATH):
    print("Cloning book repo...")
    os.chdir(TMP_DIR)
    result = subprocess.run(
        ["git", "clone", "--depth=1", "https://github.com/munificent/craftinginterpreters"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        sys.stderr.write(f"Git problems!\n{result.stderr}")
        sys.exit(1)
else:
    print("Updating book repo...")
    os.chdir(BOOK_REPO_PATH)
    result = subprocess.run(
        ["git", "pull"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        sys.stderr.write(f"Git problems!\n{result.stderr}")
        sys.exit(1)

os.chdir(BOOK_REPO_PATH)
print("Installing testing dependencies...")
result = subprocess.run(["make", "get"], stdout=open(os.devnull, 'wb'))


env = os.environ.copy()
tester = RELATIVE_JLOX_PATH
env["PYTHONPATH"] = ROOT_PATH
tester_name = "jlox"
suite = "jlox"
print(f"Running jlox test suite with Python AST-walk interpreter...")
jlox_start = time.time()
res = subprocess.run(["dart", "./tool/bin/test.dart", suite, "--interpreter", tester], env=env)
jlox_end = time.time()
if (res.returncode != 0):
    sys.exit(res.returncode)

env = os.environ.copy()
tester = RELATIVE_CLOX_PATH
tester_name = "clox"
suite = "clox"
print(f"Running clox test suite with D-lang bytecode interpreter...")
clox_start = time.time()
res = subprocess.run(["dart", "./tool/bin/test.dart", suite, "--interpreter", tester], env=env)
clox_end = time.time()
if (res.returncode != 0):
    sys.exit(res.returncode)

env = os.environ.copy()
tester = RELATIVE_CLOX_PATH
tester_name = "clox"
suite = "clox"
print(f"Running clox test suite with canonical clox interpreter...")
cclox_start = time.time()
res = subprocess.run(["dart", "./tool/bin/test.dart", suite, "--interpreter", "./build/clox"], env=env)
cclox_end = time.time()
if (res.returncode != 0):
    sys.exit(res.returncode)


print(f"\n plox test suite execution time: {jlox_end - jlox_start:.5f}\n clox test suite execution time: {clox_end - clox_start:.5f}\ncclox test suite execution time: {cclox_end - cclox_start:.5f}")
print()
print()

print("Running zoo benchmark...")
if ("bench_plox" in sys.argv):
    env = os.environ.copy()
    env["PYTHONPATH"] = ROOT_PATH
    jres = subprocess.run([RELATIVE_JLOX_PATH, "../../programs/zoo.lox"], env=env, capture_output=True)
    jtime = jres.stdout.decode("utf-8").splitlines()[0]
    print(f" plox benchmark time: {jtime}")
else:
    print(f" plox benchmark time: N/A")

cres = subprocess.run([RELATIVE_CLOX_PATH, "../../programs/zoo.lox"], capture_output=True)
ctime = cres.stdout.decode("utf-8").splitlines()[0]
ccres = subprocess.run(["./build/clox", "../../programs/zoo.lox"], capture_output=True)
cctime = ccres.stdout.decode("utf-8").splitlines()[0]
print(f" clox benchmark time: {ctime}\ncclox benchmark time: {cctime}")
