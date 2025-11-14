# Reentrancy Prevention - Cadence (Flow)

Este directorio contiene implementaciones en **Cadence** que demuestran:
1. Por qué reentrancy es **IMPOSIBLE** en Cadence por diseño
2. Cómo Resources y linear types previenen el problema automáticamente
3. No se necesitan workarounds manuales

## 🚀 Setup Rápido

### Requisitos Previos

```bash
# Instalar Flow CLI
sh -ci "$(curl -fsSL https://storage.googleapis.com/flow-cli/install.sh)"

# Verificar instalación
flow version  # Debe ser v1.18.0 o superior
```

### Instalación

```bash
# Desde el directorio cadence_defi/chapters/01-reentrancy/cadence
flow test tests/SimpleVault_test.cdc
```

## 🧪 Ejecutar Tests

### Todos los tests

```bash
flow test tests/SimpleVault_test.cdc
```

### Con output verbose

```bash
flow test --verbose tests/SimpleVault_test.cdc
```

### Test específico

```bash
flow test --filter testWithdraw tests/SimpleVault_test.cdc
```

## 📊 Tests Incluidos

### SimpleVault_test.cdc

Tests que demuestran la seguridad por diseño de Cadence:

- ✅ `testCreateVault()` - Crear vault funciona correctamente
- ✅ `testDeposit()` - Depositar tokens funciona
- ✅ `testWithdraw()` - Retirar tokens funciona
- ✅ `testMultipleWithdrawals()` - Múltiples withdrawals son seguras
- ✅ `testReentrancyIsImpossible()` - Demuestra que reentrancy no compila

**Resultado esperado**: Todos los tests pasan

## 🔐 Por Qué Reentrancy es Imposible

### 1. Resources son Linear Types

```cadence
let tokens1 <- vault.withdraw(amount: 100.0)

// ❌ El siguiente código NO COMPILA:
// let tokens2 <- vault.withdraw(amount: 50.0)
//
// ERROR: "loss of resource `tokens1`"
//
// El compilador FUERZA que manejes tokens1 primero
```

### 2. Move Semantics

```cadence
let tokens <- vault.withdraw(amount: 100.0)

// El Resource se MOVIÓ, no se copió
// Debe ser usado exactamente una vez:
destroy tokens  // o depositarlo en otro vault

// Ahora sí puedes hacer otra operación
let tokens2 <- vault.withdraw(amount: 50.0)
destroy tokens2
```

### 3. Ownership Claro

```cadence
pub resource Vault {
    pub var balance: UFix64

    // Solo el DUEÑO del Resource puede llamar withdraw()
    pub fun withdraw(amount: UFix64): @Token {
        self.balance = self.balance - amount
        return <- create Token(balance: amount)
    }
}

// No hay msg.sender confuso
// La capability ES la autorización
```

## 📈 Comparación con Solidity

### Solidity (Vulnerable)

```solidity
function withdraw() public {
    uint balance = balances[msg.sender];
    msg.sender.call{value: balance}("");  // ⚠️ Reentrancy AQUÍ
    balances[msg.sender] = 0;  // ❌ Demasiado tarde
}
```

**Problemas:**
- Vulnerable por defecto
- Requiere workarounds manuales
- Fácil cometer errores
- ~2,500 gas overhead con ReentrancyGuard

### Solidity (Con Protección)

```solidity
function withdraw() public nonReentrant {  // ← Debes recordar esto
    uint balance = balances[msg.sender];
    balances[msg.sender] = 0;  // ← Debes recordar el orden
    msg.sender.call{value: balance}("");
}
```

**Mejora pero:**
- Aún requiere disciplina
- Puedes olvidar el modifier
- Costo extra de gas

### Cadence (Seguro por Diseño)

```cadence
access(all) fun withdraw(amount: UFix64): @Token {
    pre {
        self.balance >= amount
    }

    self.balance = self.balance - amount
    return <- create Token(balance: amount)
}
```

**Ventajas:**
- ✅ Seguro por defecto
- ✅ No necesitas recordar nada
- ✅ Compilador te protege
- ✅ Zero overhead de gas
- ✅ Imposible cometer errores

## 🎯 Para Videos/Demos

### Demo 1: Código que funciona

```bash
# Ejecutar todos los tests
flow test tests/SimpleVault_test.cdc
```

Muestra cómo el código Cadence funciona correctamente sin necesitar protecciones especiales.

### Demo 2: Código que NO compila

Abre `tests/SimpleVault_test.cdc` y descomenta las líneas en `testReentrancyIsImpossible()`:

```cadence
let tokens1 <- vault.withdraw(amount: 30.0)
let tokens2 <- vault.withdraw(amount: 20.0)  // Descomentar esta línea
```

Intenta ejecutar:
```bash
flow test tests/SimpleVault_test.cdc
```

**Resultado**: Error de compilación
```
error: loss of resource `tokens1`
```

¡El compilador te OBLIGA a manejar el resource antes de continuar!

### Demo 3: Flow Playground (Online)

Si no quieres instalar Flow CLI:

1. Ve a https://play.flow.com/
2. Copia el contenido de `SimpleVault.cdc`
3. Ejecuta en el navegador
4. Experimenta con el código

## 📁 Estructura de Archivos

```
cadence/
├── README.md                    # Este archivo
├── SimpleVault.cdc              # Contrato principal (standalone)
├── solucion.cdc                 # Código educativo (con dependencias)
│
├── tests/
│   └── SimpleVault_test.cdc    # Tests completos
│
└── setup.sh                     # Script de instalación automática
```

## 🐛 Troubleshooting

### Error: "flow: command not found"

```bash
# Re-instalar Flow CLI
sh -ci "$(curl -fsSL https://storage.googleapis.com/flow-cli/install.sh)"

# Añadir a PATH
export PATH="$HOME/.local/bin:$PATH"
```

### Error: "Version warning"

```bash
# Actualizar a la última versión
flow version --check-updates
```

### Tests fallan con "internal error"

Esto puede ocurrir con versiones antiguas de Flow CLI. Soluciones:

1. **Actualizar Flow CLI a v1.18.0+**
2. **Usar Flow Playground** (online, no requiere instalación)
3. **Verificar sintaxis** del código Cadence 1.0

## 📚 Recursos

- [Flow Developer Portal](https://developers.flow.com/)
- [Cadence Language Reference](https://developers.flow.com/cadence/language)
- [Flow Playground](https://play.flow.com/)
- [Resource-Oriented Programming](https://developers.flow.com/cadence/language/resources)

## 🎓 Lecciones Clave

### ✅ En Cadence

1. **Reentrancy es imposible por diseño**
   - Resources son linear types
   - El compilador fuerza manejo correcto
   - No necesitas pensar en ello

2. **Zero overhead de seguridad**
   - Verificación en compile-time
   - No costo extra de gas
   - Mejor performance

3. **Mejor developer experience**
   - Código más simple
   - Menos bugs posibles
   - Onboarding más rápido

### ⚠️ Comparado con Solidity

| Aspecto | Solidity | Cadence |
|---------|----------|---------|
| Vulnerable por defecto | ✅ Sí | ❌ No |
| Requiere protección manual | ✅ Sí | ❌ No |
| Costo de gas extra | ~2,500 | 0 |
| Puede olvidarse | ✅ Sí | ❌ Imposible |
| Compilador previene | ❌ No | ✅ Sí |

## 🚀 Próximos Pasos

1. Ejecuta los tests localmente
2. Experimenta modificando el código
3. Intenta escribir código "vulnerable" (no compilará)
4. Compara con los tests de Solidity en `../evm/`

**Conclusión**: En Cadence, la seguridad ante reentrancy es gratis y automática. No necesitas pensar en ello.
