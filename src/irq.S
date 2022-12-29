.globl irq_vector_init
// Fixe la valeur du registre VBAR_EL2 à l'adresse vectors (qui contient la table d'interruption)
// Ce registre sera utilisé par le niveau EL2 comme adresse de base pour ses exceptions
irq_vector_init:
  adr x0, vectors       // load VBAR_EL2 with virtual
  msr vbar_el2, x0        // vector table address
  ret

.globl enable_irq
// Fixe le bit 2 de DAIF à 0 = non masqué
enable_irq:
  msr    daifclr, #2
  ret

.globl disable_irq
// Fixe le bit 2 de DAIF à 1 = masqué
disable_irq:
  msr daifset, #2
  ret
