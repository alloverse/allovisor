#include "allovisor_version.h"

#define STR_VALUE(arg)      #arg
#define STR(name) STR_VALUE(name)


const char *GetAllovisorVersion()
{
    return STR(ALLOVISOR_VERSION);
}
const char *GetAllovisorNumericVersion()
{
    return STR(ALLOVISOR_NUMERIC_VERSION);
}
const char *GetAllovisorGitHash()
{
    return STR(ALLOVISOR_HASH);
}
