import sys
import os
import io

def define_type(out_file: io.TextIOWrapper, base_name: str, class_name: str, field_list: str):
    out_file.write(f"class {class_name}({base_name}):\n")
    out_file.write(f"    def __init__(self, {field_list}):\n")
    for field in [f.strip() for f in field_list.split(",")]:
        name, *_ = [sf.strip() for sf in field.split(":")]
        out_file.write(f"        self.{field} = {name}\n")
    out_file.write("\n")
    out_file.write(f"    def accept(self, visitor: {base_name}.Visitor):\n")
    out_file.write(f"        return visitor.visit_{class_name.lower()}_{base_name.lower()}(self)\n")
    out_file.write("\n")

def define_ast(output_dir: str, base_name: str, types: list[str], imports: list[str] = []):
    type_datums = [[st.strip() for st in sub_type.split(":", 1)] for sub_type in types]

    output_path = os.path.join(output_dir, base_name.lower() + ".py")
    out_file = open(output_path, "w")

    out_file.write("# This file was automatically generated by ./tool/generate_ast.py\n\n")
    out_file.write("from __future__ import annotations\n")
    out_file.write("import abc\n\n")
    out_file.write("from ..token import Token\n")
    for imp in imports:
        out_file.write(f"from .{imp.lower()} import {imp}\n")
    out_file.write("\n")

    out_file.write(f"class {base_name}:\n")
    out_file.write(f"    @abc.abstractmethod\n    def accept(self, visitor: {base_name}):\n        pass\n\n")
    out_file.write(f"class {base_name}Visitor(abc.ABC):\n")
    for class_name, _ in type_datums:
        out_file.write(f"    @abc.abstractmethod\n    def visit_{class_name.lower()}_{base_name.lower()}(self, {base_name.lower()}: {class_name}):\n        pass\n\n")
    out_file.write("\n")

    for class_name, fields in type_datums:
        define_type(out_file, base_name, class_name, fields)

    out_file.write("\n")
    out_file.close()


def main(args: list[str]):
    if len(args) != 1:
        sys.stderr.write("Usage: generate_ast <output_dir>")
        sys.exit(64)

    if not os.path.exists(args[0]):
        os.makedirs(args[0])

    define_ast(args[0], "Expr", [
        "Assign   : name: Token, value: Expr",
        "Binary   : left: Expr, operator: Token, right: Expr",
        "Grouping : expression: Expr",
        "Literal  : value",
        "Unary    : operator: Token, right: Expr",
        "Variable : name: Token"
    ])

    define_ast(args[0], "Stmt", [
        "Block      : statements: list[Expr]",
        "Expression : expression: Expr",
        "Print      : expression: Expr",
        "Var        : name: Token, initializer: Expr",
    ], ["Expr"])

    init_path = os.path.join(args[0], "__init__.py")
    init_file = open(init_path, "w")
    init_file.write("# This file was automatically generated by ./tool/generate_ast.py\n\n")
    for export in ["Expr", "Stmt"]:
        init_file.write(f"from . import {export.lower()}\n")
    init_file.write("\n")
    init_file.close()



if __name__ == "__main__":
    own_dir = os.path.dirname(os.path.realpath(__file__))
    main([os.path.join(own_dir, "..", "ast")])
