# ============================================================================
# Makefile - Evaluador de expresiones (x86-64 / NASM / Linux, sin libc)
# ----------------------------------------------------------------------------
# Ensambla cada modulo .asm por separado (nasm -f elf64) y enlaza todos los
# objetos con ld en un ejecutable estatico.
#
# Uso:
#   make                -> compila el ejecutable "evaluator"
#   make SCALE=OFF      -> aritmetica entera (sin punto fijo de 2 decimales)
#   make run            -> lo ejecuta
#   make test           -> pruebas rapidas
#   make clean          -> borra objetos y ejecutable
#
# SCALE=ON (por defecto) activa el Extra 5: toda la aritmetica de la
# expresion trabaja escalada x100 (-dFIXED2) y el resultado se imprime con
# print_fixed2.  SCALE=OFF desactiva esa definicion y se imprime entero.
# ============================================================================

NASM      := nasm
LD        := ld

# -w-reloc-rel-dword / -w-reloc-abs-qword: silencian los avisos de
# relocalizaciones entre secciones (los "lea" de tokens / step_buf y la tabla
# de punteros a mensajes de errors.asm). Son normales y correctas en un enlace
# estatico no-PIE; el resto de avisos de -Wall sigue activo.
NASMFLAGS := -f elf64 -Wall -w-reloc-rel-dword -w-reloc-abs-qword
LDFLAGS   :=

# --- Factor de escala (Extra 5) ---------------------------------------------
SCALE ?= ON
ifeq ($(SCALE),ON)
DEFS := -dFIXED2
else
DEFS :=
endif

# --- Modulos ----------------------------------------------------------------
MODULES := main io parser evaluator operations variables errors display
OBJS    := $(addsuffix .o,$(MODULES))
TARGET  := evaluator

# --- Reglas -----------------------------------------------------------------
all: $(TARGET)

# Enlaza todos los objetos en un unico ejecutable ELF64 estatico.
$(TARGET): $(OBJS)
	$(LD) $(LDFLAGS) $(OBJS) -o $@

# Regla generica: cada .asm se ensambla por separado.
%.o: %.asm
	$(NASM) $(NASMFLAGS) $(DEFS) $< -o $@

# Recompila todo si cambia el Makefile (afecta a DEFS).
$(OBJS): Makefile

run: $(TARGET)
	./$(TARGET)

test: $(TARGET)
	@echo "2+3" | ./$(TARGET)
	@echo "2x + 6y + 3x - x*z / 8 + 25, x=50, y=5, z=20" | ./$(TARGET)
	@echo "2*(3+4)" | ./$(TARGET)
	@echo "(1+2)*(3+(4*5))" | ./$(TARGET)
	@echo "2**10" | ./$(TARGET)
	@echo "7%3" | ./$(TARGET)
	@echo "e(1)" | ./$(TARGET)
	@echo "10/0" | ./$(TARGET)

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all run test clean
