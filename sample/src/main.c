#include <stdio.h>
#include "foo.h"

int main(void) {
    printf("Starting the 'app' executable target...\n");
    
    // Call the function compiled inside our static library dependency
    print_message();
    
    printf("Execution completed successfully.\n");
    return 0;
}
