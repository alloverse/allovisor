#include "allovisor_version.h"

#define STR_VALUE(arg)      #arg
#define STR(name) STR_VALUE(name)

#ifdef WIN32
#define EXPORT extern __declspec(dllexport)
#else
#define EXPORT
#endif


EXPORT const char *GetAllovisorVersion()
{
    return STR(ALLOVISOR_VERSION);
}
EXPORT const char *GetAllovisorNumericVersion()
{
    return STR(ALLOVISOR_NUMERIC_VERSION);
}
EXPORT const char *GetAllovisorGitHash()
{
    return STR(ALLOVISOR_HASH);
}
