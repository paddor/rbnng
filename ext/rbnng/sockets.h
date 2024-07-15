/*
 * Copyright (c) 2021 Adib Saad
 *
 */

#ifndef RBNNG_SOCKETS_H
#define RBNNG_SOCKETS_H

#include <ruby.h>

extern VALUE rbnng_SocketModule;
extern VALUE rbnng_SocketBaseClass;
extern void
rbnng_sockets_Init(void);
extern void
rbnng_rep0_Init(void);
extern void
rbnng_req0_Init(void);
extern void
rbnng_pair_Init(void);
extern void
rbnng_pub0_Init(void);
extern void
rbnng_sub0_Init(void);
extern void
rbnng_bus0_Init(void);
extern void
rbnng_surveyor0_Init(void);
extern void
rbnng_respondent0_Init(void);
extern void
rbnng_push0_Init(void);
extern void
rbnng_pull0_Init(void);

#endif
