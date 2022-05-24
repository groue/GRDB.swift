#include <unistd.h>
#include <mach/mach.h>
#include "getThreadsCount.h"

// https://stackoverflow.com/a/21571172/525656
int getThreadsCount(void) {
    thread_array_t threadList;
    mach_msg_type_number_t threadCount;
    task_t task;

    kern_return_t kernReturn = task_for_pid(mach_task_self(), getpid(), &task);
    if (kernReturn != KERN_SUCCESS) {
        return -1;
    }

    kernReturn = task_threads(task, &threadList, &threadCount);
    if (kernReturn != KERN_SUCCESS) {
        return -1;
    }
    vm_deallocate (mach_task_self(), (vm_address_t)threadList, threadCount * sizeof(thread_act_t));

    return threadCount;
}
