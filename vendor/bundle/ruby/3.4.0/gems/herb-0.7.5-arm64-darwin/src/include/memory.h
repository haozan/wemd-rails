#ifndef HERB_MEMORY_H
#define HERB_MEMORY_H

#include <stddef.h>

void* safe_malloc(size_t size);
void* safe_realloc(void* pointer, size_t new_size);

void* nullable_safe_malloc(size_t size);
void* nullable_safe_realloc(void* pointer, size_t new_size);

#endif
