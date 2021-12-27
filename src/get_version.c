#include "allovisor_version.h"
#include "util.h"

#define STR_VALUE(arg)      #arg
#define STR(name) STR_VALUE(name)

ALLOVISOR_EXPORT const char *GetAllovisorVersion()
{
    return STR(ALLOVISOR_VERSION);
}
ALLOVISOR_EXPORT const char *GetAllovisorNumericVersion()
{
    return STR(ALLOVISOR_NUMERIC_VERSION);
}
ALLOVISOR_EXPORT const char *GetAllovisorGitHash()
{
    return STR(ALLOVISOR_HASH);
}
