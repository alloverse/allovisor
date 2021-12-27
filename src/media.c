#include <allonet/allonet.h>
#include "util.h"

ALLOVISOR_EXPORT void visor_media_init()
{
    allo_libav_initialize();
}