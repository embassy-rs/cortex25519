set history save on
set confirm off
target remote :1234
# target remote | qemu-system-arm -cpu cortex-m4 -machine lm3s6965evb -nographic -gdb stdio -S -kernel empty.elf

# set print asm-demangle on
# monitor arm semihosting enable

load
