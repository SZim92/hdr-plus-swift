#include <stdio.h>
#include "../RawEnvironment.h"

int main() {
#if DISABLE_JXL_SUPPORT
    printf("JPEG XL support is disabled\n");
#else
    printf("JPEG XL support is enabled\n");
#endif
    return 0;
} 