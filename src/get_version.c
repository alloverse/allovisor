#include "allovisor_version.h"
#define str(s) #s

const char *GetAllovisorVersion()
{
    return str(ALLOVISOR_VERSION);
}
const char *GetAllovisorNumericVersion()
{
    return str(ALLOVISOR_NUMERIC_VERSION);
}
const char *GetAllovisorGitHash()
{
    return str(ALLOVISOR_HASH);
}
