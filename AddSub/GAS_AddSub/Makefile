SRC   = sum_sub.s
OBJ   = sum_sub.o
BIN   = sum_sub
AS    = as
LD    = ld

all: $(BIN)

$(BIN): $(OBJ)
	$(LD) $(OBJ) -o $(BIN)

$(OBJ): $(SRC)
	$(AS) $(SRC) -o $(OBJ)

clean:
	rm -f $(OBJ) $(BIN)

.PHONY: all clean
