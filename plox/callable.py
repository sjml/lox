import abc
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .interpreter import Interpreter

class Callable(abc.ABC):
    if TYPE_CHECKING:
        def call(self, interpreter: Interpreter, arguments: list[object]) -> object:
            pass
    else:
        def call(self, interpreter, arguments):
            pass

    def arity(self) -> int:
        pass
