import sys
import os
import subprocess

ROOT_PATH = os.path.realpath(os.path.join(os.path.dirname(__file__), ".."))
TMP_DIR = os.path.join(ROOT_PATH, "test", "tmp")
BOOK_REPO_PATH = os.path.join(TMP_DIR, "craftinginterpreters")
RELATIVE_JLOX_PATH = "../../../plox.sh"

JLOX_TESTS = {
     5 : "chap05_representing",
     6 : "chap06_parsing",
     7 : "chap07_evaluating",
     8 : "chap08_statements",
     9 : "chap09_control",
    10 : "chap10_functions",
    11 : "chap11_resolving",
    12 : "chap12_classes",
    13 : "chap13_inheritance",
}

CLOX_TESTS = {
    14 : "chap14_chunks",
    15 : "chap15_virtual",
    16 : "chap16_scanning",
    17 : "chap17_compiling",
    18 : "chap18_types",
    19 : "chap19_strings",
    20 : "chap20_hash",
    21 : "chap21_global",
    22 : "chap22_local",
    23 : "chap23_jumping",
    24 : "chap24_calls",
    25 : "chap25_closures",
    26 : "chap26_garbage",
    27 : "chap27_classes",
    28 : "chap28_methods",
    29 : "chap29_superclasses",
    30 : "chap30_optimization",
}

args = sys.argv[1:]
if len(args) < 1:
    sys.stderr.write("Give a chapter number to test!\n")
    sys.exit(1)
try:
    chapter = int(args[0])
except:
    sys.stderr.write("Chapter number has to be integer!\n")
    sys.exit(1)
if chapter not in JLOX_TESTS:
    sys.stderr.write("Invalid chapter for testing!\n")
    sys.exit(1)

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
print("Installing dependencies...")
result = subprocess.run(["make", "get"], stdout=open(os.devnull, 'wb'))

print(f"Running tests for chapter {chapter}...")
subprocess.run(["dart", "./tool/bin/test.dart", JLOX_TESTS[chapter], "--interpreter", RELATIVE_JLOX_PATH])
