module util;

size_t growCapacity(size_t currentCap)
{
    if (currentCap < 8)
        return 8;
    return currentCap * 2;
}
