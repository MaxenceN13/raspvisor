#include "arm/mmu.h"
#include "arm/sysregs.h"
#include "mm.h"
#include "peripherals/base.h"

.section ".text.boot"

.globl _start
// Les 4 coeurs sont lancés en parallèle. Le coeur 0 lance le programme master (le reste est en attente)
_start:
  // https://developer.arm.com/documentation/100403/0200/register-descriptions/aarch64-system-registers/mpidr-el1--multiprocessor-affinity-register--el1
  mrs x0, mpidr_el1 // Récupère l'id du coeur (MPIDR_EL1 : Multiprocessor Affinity Register, read-only)
  and x0, x0,#0xFF  // Masque les 8 bits de poids fort
  cbz x0, master    // Si l'id est 0, lance le programme master
  b proc_hang

// Boucle infinie (en attente d'une interruption)
proc_hang:
  b proc_hang

master:
  // Initial EL is 3
  // Change EL from 3 to 2
  // https://developer.arm.com/documentation/ddi0601/2022-12/AArch64-Registers/SCTLR-EL2--System-Control-Register--EL2-
  ldr x0, =SCTLR_VALUE_MMU_DISABLED   // Récupère la valeur de SCTLR_EL2 (System Control Register, EL2)
  msr sctlr_el2, x0                   // Change la valeur de SCTLR_EL2 par la valeur de x0 (SCTLR_VALUE_MMU_DISABLED)

  // https://developer.arm.com/documentation/ddi0601/2022-12/AArch64-Registers/HCR-EL2--Hypervisor-Configuration-Register
  ldr x0, =HCR_VALUE                  // Récupère la valeur de HCR_EL2 (Hypervisor Configuration Register, EL2)
  msr hcr_el2, x0                     // Change la valeur de HCR_EL2 par la valeur de x0 (HCR_VALUE)

  // https://developer.arm.com/documentation/ddi0601/2022-12/AArch64-Registers/SCR-EL3--Secure-Configuration-Register
  ldr x0, =SCR_VALUE                  // Récupère la valeur de SCR_EL3 (Secure Configuration Register, EL3)
  msr scr_el3, x0                     // Change la valeur de SCR_EL3 par la valeur de x0 (SCR_VALUE)

  // https://developer.arm.com/documentation/ddi0601/2022-12/AArch64-Registers/SPSR-EL3--Saved-Program-Status-Register--EL3-
  ldr x0, =SPSR_VALUE                 // Récupère la valeur de SPSR_EL3 (Saved Program Status Register, EL3)
  msr spsr_el3, x0                    // Change la valeur de SPSR_EL3 par la valeur de x0 (SPSR_VALUE)

  // https://developer.arm.com/documentation/ddi0601/2022-12/AArch64-Registers/ELR-EL3--Exception-Link-Register--EL3-
  adr x0, el2_entry                   // Récupère l'adresse de la fonction el2_entry
  msr elr_el3, x0                     // Change la valeur de ELR_EL3 (Exception Link Register, EL3) par la valeur de x0 (l'adresse de la fonction el2_entry) ce qui permet de lancer la fonction el2_entry au prochain changement de niveau d'exécution de EL3 à EL2
  
  eret                                // Retourne à l'exception level 2 (EL3 -> EL2)

el2_entry:
  adr x0, bss_begin             // Récupère l'adresse de la variable bss_begin
  adr x1, bss_end               // Récupère l'adresse de la variable bss_end
  sub x1, x1, x0                // x1 = x1 - x0 (taille de la zone bss)
  bl  memzero                   // Appelle la fonction memzero avec les paramètres x0 et x1 (adresse de bss_begin et taille de la zone bss) qui est définie dans "utils.S"

  bl  __create_page_tables      // Appelle la fonction __create_page_tables

  // https://developer.arm.com/documentation/100403/0200/register-descriptions/aarch64-system-registers/sp_el2--stack-pointer--el2
  mov x0, #VA_START             // x0 = VA_START
  add sp, x0, #LOW_MEMORY       // sp = VA_START + LOW_MEMORY (stack pointer qui pointe vers la fin de la zone LOW_MEMORY)

  // https://developer.arm.com/documentation/100403/0200/register-descriptions/aarch64-system-registers/ttbr0-el2--translation-table-base-register-0--el2
  adrp  x0, pg_dir              // Récupère l'adresse de la variable pg_dir (page directory qui contient les tables de pages)
  msr ttbr0_el2, x0             // Change la valeur de TTBR0_EL2 (Translation Table Base Register 0, EL2) par la valeur de x0 (l'adresse de la variable pg_dir)

  // https://developer.arm.com/documentation/100403/0200/register-descriptions/aarch64-system-registers/tcr-el2--translation-control-register--el2
  ldr x0, =(TCR_VALUE)          // Récupère la valeur de TCR_EL2 (Translation Control Register, EL2)
  msr tcr_el2, x0               // Change la valeur de TCR_EL2 par la valeur de x0 (TCR_VALUE)

  // https://developer.arm.com/documentation/100403/0200/register-descriptions/aarch64-system-registers/vtcr-el2--virtualization-translation-control-register--el2
  ldr x0, =(VTCR_VALUE)         // Récupère la valeur de VTCR_EL2 (Virtualization Translation Control Register, EL2)
  msr vtcr_el2, x0              // Change la valeur de VTCR_EL2 par la valeur de x0 (VTCR_VALUE)

  // https://developer.arm.com/documentation/100403/0200/register-descriptions/aarch64-system-registers/vttbr-el2--virtualization-translation-table-base-register--el2
  ldr x0, =(MAIR_VALUE)         // Récupère la valeur de MAIR_EL2 (Memory Attribute Indirection Register, EL2)
  msr mair_el2, x0              // Change la valeur de MAIR_EL2 par la valeur de x0 (MAIR_VALUE)

  // https://developer.arm.com/documentation/100403/0200/register-descriptions/aarch64-system-registers/vttbr-el2--virtualization-translation-table-base-register--el2
  // clear TLB
  tlbi alle1                    // TLB Invalidate All Entries, EL1 (TLB = Translation Lookaside Buffer)

  ldr x2, =hypervisor_main      // Récupère l'adresse de la fonction hypervisor_main

  mov x0, #SCTLR_MMU_ENABLED    // x0 = SCTLR_MMU_ENABLED (SCTLR_EL2 = System Control Register, EL2)
  dsb ish                       // Data Synchronization Barrier, Inner Shareable (DSB = Data Synchronization Barrier)
  isb                           // Instruction Synchronization Barrier (ISB = Instruction Synchronization Barrier)
  msr sctlr_el2, x0             // Change la valeur de SCTLR_EL2 par la valeur de x0 (SCTLR_MMU_ENABLED)
  isb                           // Instruction Synchronization Barrier (ISB = Instruction Synchronization Barrier)

  br  x2                        // Retourne à l'adresse de la fonction hypervisor_main

  .macro  create_pgd_entry, tbl, virt, tmp1, tmp2               // Créer une entrée dans la page directory
  create_table_entry \tbl, \virt, PGD_SHIFT, \tmp1, \tmp2   
  create_table_entry \tbl, \virt, PUD_SHIFT, \tmp1, \tmp2   
  .endm

  .macro  create_table_entry, tbl, virt, shift, tmp1, tmp2      // Créer une entrée dans la table de pages
  lsr \tmp1, \virt, #\shift                                 
  and \tmp1, \tmp1, #PTRS_PER_TABLE - 1                         // table index
  add \tmp2, \tbl, #PAGE_SIZE                               
  orr \tmp2, \tmp2, #MM_TYPE_PAGE_TABLE                         // next level table page
  str \tmp2, [\tbl, \tmp1, lsl #3]                              // store the entry
  add \tbl, \tbl, #PAGE_SIZE                                    // next level table page
  .endm 

  .macro  create_block_map, tbl, phys, start, end, flags, tmp1  // Créer une entrée dans la table de pages
  lsr \start, \start, #SECTION_SHIFT
  and \start, \start, #PTRS_PER_TABLE - 1                       // table index
  lsr \end, \end, #SECTION_SHIFT
  and \end, \end, #PTRS_PER_TABLE - 1                           // table end index
  lsr \phys, \phys, #SECTION_SHIFT                              
  mov \tmp1, #\flags
  orr \phys, \tmp1, \phys, lsl #SECTION_SHIFT                   // table entry
9999: str \phys, [\tbl, \start, lsl #3]                         // store the entry
  add \start, \start, #1                                        // next entry
  add \phys, \phys, #SECTION_SIZE                               // next block
  cmp \start, \end
  b.ls  9999b
  .endm

__create_page_tables:
  mov x29, x30                                          // save return address

  adrp  x0, pg_dir                                      // x0 = pg_dir (adrp = Add Relative Page)
  mov x1, #PG_DIR_SIZE                                  // x1 = PG_DIR_SIZE
  bl  memzero                                           // memzero(pg_dir, PG_DIR_SIZE)

  adrp  x0, pg_dir                                      // x0 = pg_dir
  mov x1, #VA_START                                     // x1 = VA_START (VA_START représente l'adresse virtuelle de début de la mémoire physique)
  create_pgd_entry x0, x1, x2, x3                       // create_pgd_entry(pg_dir, VA_START, x2, x3)

  /* Mapping kernel and init stack*/
  mov   x1, xzr                                         // start mapping from physical offset 0
  mov   x2, #VA_START                                   // first virtual address
  ldr x3, =(VA_START + DEVICE_BASE - SECTION_SIZE)      // last virtual address
  create_block_map x0, x1, x2, x3, MMU_FLAGS, x4        // create_block_map(pg_dir, 0, VA_START, VA_START + DEVICE_BASE - SECTION_SIZE, MMU_FLAGS, x4)

  /* Mapping device memory*/
  mov   x1, #DEVICE_BASE                                // start mapping from device base address
  ldr   x2, =(VA_START + DEVICE_BASE)                   // first virtual address
  ldr x3, =(VA_START + PHYS_MEMORY_SIZE - SECTION_SIZE) // last virtual address
  create_block_map x0, x1, x2, x3, MMU_DEVICE_FLAGS, x4 // create_block_map(pg_dir, DEVICE_BASE, VA_START + DEVICE_BASE, VA_START + PHYS_MEMORY_SIZE - SECTION_SIZE, MMU_DEVICE_FLAGS, x4)

  mov x30, x29                                          // restore return address
  ret

