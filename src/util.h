#ifdef WIN32
#define ALLOVISOR_EXPORT extern __declspec(dllexport)
#else
#define ALLOVISOR_EXPORT
#endif