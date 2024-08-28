
class LoxReturn(RuntimeError):
    def __init__(self, value: object) -> None:
        self.value = value
