#include <stddef.h>
#include <stdint.h>

#include "irq.h"
#include "mini_uart.h"
#include "printf.h"
#include "sched.h"
#include "task.h"
#include "timer.h"
#include "utils.h"
#include "mm.h"
#include "sd.h"
#include "debug.h"
#include "loader.h"

void hypervisor_main() {
  // Initialise l'UART sur la broche GPIO14 et GPIO15
  uart_init();
  // Initialise le système de printf pour utiliser l'UART comme sortie (putc est défini dans mini_uart.c et utilise uart_send)
  init_printf(NULL, putc);
  printf("=== raspvisor ===\n");

  // Réserve de la mémoire pour la tâche (current est défini dans sched.c et correspond à la tâche initial)
  init_task_console(current);
  // Donne le nom IDLE à la tâche current
  init_initial_task();
  // Initialise la variable vbar_el2 avec le contenue du vecteur d'interruption 
  irq_vector_init();
  // Définit la valeur de fin du timer (qui déclenche une interruption)
  timer_init();
  // Désactiver les interruptions IRQ en fixant la valeur du reg DAIFCLR à 2 (ce qui met à 0 le bit 2 du registre DAIF)
  disable_irq();
  // Active certaines interruptions (lequel ?)
  enable_interrupt_controller();

  if (sd_init() < 0)
    PANIC("sd_init() failed.");

  struct raw_binary_loader_args bl_args1 = {
    .load_addr = 0x0,
    .entry_point = 0x0,
    .sp = 0x100000,
    .filename = "mini-os.bin",
  };
  if (create_task(raw_binary_loader, &bl_args1) < 0) {
    printf("error while starting task");
    return;
  }

  struct raw_binary_loader_args bl_args2 = {
    .load_addr = 0x0,
    .entry_point = 0x0,
    .sp = 0x100000,
    .filename = "echo.bin",
  };
  if (create_task(raw_binary_loader, &bl_args2) < 0) {
    printf("error while starting task");
    return;
  }

  struct raw_binary_loader_args bl_args3 = {
    .load_addr = 0x0,
    .entry_point = 0x0,
    .sp = 0x100000,
    .filename = "mini-os.bin",
  };
  if (create_task(raw_binary_loader, &bl_args3) < 0) {
    printf("error while starting task #2");
    return;
  }

  struct raw_binary_loader_args bl_args4 = {
    .load_addr = 0x0,
    .entry_point = 0x0,
    .sp = 0x100000,
    .filename = "echo.bin",
  };
  if (create_task(raw_binary_loader, &bl_args4) < 0) {
    printf("error while starting task");
    return;
  }

  struct raw_binary_loader_args bl_args5 = {
    .load_addr = 0x0,
    .entry_point = 0x0,
    .sp = 0x100000,
    .filename = "mini-os.bin",
  };
  if (create_task(raw_binary_loader, &bl_args5) < 0) {
    printf("error while starting task");
    return;
  }

  while (1) {
    disable_irq();
    schedule();
    enable_irq();
  }
}
