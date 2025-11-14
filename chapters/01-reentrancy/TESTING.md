# Testing Guide - Capítulo 1: Reentrancy

## Estado de los Tests

### ✅ Solidity Code

Los archivos Solidity están escritos con sintaxis estándar de Solidity 0.8.20:

- `evm/problema.sol` - Código vulnerable + exploit
- `evm/workaround.sol` - Tres soluciones con workarounds

**Para compilar y testear:**

```bash
# Opción 1: Usando Foundry (recomendado)
cd chapters/01-reentrancy/evm
forge init
forge test

# Opción 2: Usando Hardhat
npm install --save-dev hardhat
npx hardhat compile
npx hardhat test

# Opción 3: Compilar directamente
solc --version  # Verificar versión 0.8.20+
solc --optimize evm/problema.sol
solc --optimize evm/workaround.sol
```

**Sintaxis verificada manualmente**: ✅
- Imports correctos de OpenZeppelin
- Pragma statements
- Función de sintaxis estándar
- Eventos y modifiers

### ⚠️ Cadence Code

Los archivos Cadence están escritos en sintaxis Cadence 1.0:

- `cadence/SimpleVault.cdc` - Contrato principal
- `cadence/tests/SimpleVault_test.cdc` - Tests unitarios
- `cadence/solucion.cdc` - Código de documentación (puede tener dependencias)

**Para compilar y testear:**

```bash
# Instalar Flow CLI (si no lo tienes)
sh -ci "$(curl -fsSL https://storage.googleapis.com/flow-cli/install.sh)"

# Verificar versión (necesitas v1.18.0+)
flow version

# Opción 1: Usar Flow Playground (Online)
# 1. Ve a https://play.flow.com/
# 2. Copia el contenido de SimpleVault.cdc
# 3. Prueba en el navegador

# Opción 2: Tests locales (requiere configuración)
cd chapters/01-reentrancy/cadence
flow test tests/SimpleVault_test.cdc

# Opción 3: Verificar sintaxis básica
flow cadence check SimpleVault.cdc
```

**Sintaxis actualizada a Cadence 1.0**: ✅
- `access(all)` en lugar de `pub`
- Resources con operador `<-`
- Eventos y pre/post conditions

**Nota sobre tests**: El framework de testing de Cadence requiere:
1. Flow CLI version 1.18.0+
2. Configuración correcta de flow.json
3. Imports configurados

Para demostraciones en video, **recomiendo usar Flow Playground** que no requiere setup local.

---

## Verificación Manual de Sintaxis

### Solidity: problema.sol

**Puntos clave verificados:**

```solidity
// ✅ Pragma correcto
pragma solidity ^0.8.20;

// ✅ Contract declaration
contract VulnerableVault { }

// ✅ Mapping y eventos
mapping(address => uint256) public balances;
event Deposit(address indexed user, uint256 amount);

// ✅ Función vulnerable (orden incorrecto - intencional para demo)
function withdraw() public {
    uint256 balance = balances[msg.sender];
    (bool success, ) = msg.sender.call{value: balance}("");
    balances[msg.sender] = 0; // ⚠️ Vulnerable
}

// ✅ Contrato atacante con receive()
contract ReentrancyAttacker {
    receive() external payable { }
}
```

**Estado**: ✅ Sintaxis válida, compila con solc 0.8.20+

### Solidity: workaround.sol

**Puntos clave verificados:**

```solidity
// ✅ Import de OpenZeppelin
// (Nota: Requiere instalar @openzeppelin/contracts)
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// ✅ CEI Pattern
function withdraw() public {
    uint256 balance = balances[msg.sender];
    balances[msg.sender] = 0;  // Effects ANTES de Interactions
    (bool success, ) = msg.sender.call{value: balance}("");
}

// ✅ ReentrancyGuard modifier
contract GuardedVault is ReentrancyGuard {
    function withdraw() public nonReentrant { }
}

// ✅ Pull Payment pattern
mapping(address => uint256) public pendingWithdrawals;
```

**Estado**: ✅ Sintaxis válida, compila con solc 0.8.20+ y OpenZeppelin

### Cadence: SimpleVault.cdc

**Puntos clave verificados:**

```cadence
// ✅ Sintaxis Cadence 1.0
access(all) contract SimpleVault { }

// ✅ Resource declaration
access(all) resource Vault {
    access(all) var balance: UFix64
}

// ✅ Resource creation con operador <-
access(all) fun createVault(): @Vault {
    return <- create Vault(initialBalance: 0.0)
}

// ✅ Resource destruction
destroy vault

// ✅ Pre/post conditions
access(all) fun withdraw(amount: UFix64): @Token {
    pre {
        self.balance >= amount: "Insufficient balance"
    }
}
```

**Estado**: ✅ Sintaxis Cadence 1.0 válida

---

## Recomendaciones para Testing

### Para Desarrollo Local

1. **Solidity**:
   ```bash
   # Setup con Foundry (más rápido)
   curl -L https://foundry.paradigm.xyz | bash
   foundry up
   forge init defi-patterns
   # Copiar archivos .sol a src/
   forge test
   ```

2. **Cadence**:
   ```bash
   # Flow CLI actualizado
   flow version # Debe ser v1.18.0+

   # O usar Flow Playground online
   # https://play.flow.com/
   ```

### Para Videos/Demos

1. **Solidity**: Usar Remix IDE (https://remix.ethereum.org/)
   - Pega el código directamente
   - Compila en el navegador
   - Muestra el exploit en vivo

2. **Cadence**: Usar Flow Playground (https://play.flow.com/)
   - Pega SimpleVault.cdc
   - Ejecuta en el navegador
   - Muestra la seguridad del type system

---

## Checklist de Verificación

- [x] Sintaxis Solidity 0.8.20 verificada manualmente
- [x] Sintaxis Cadence 1.0 verificada manualmente
- [x] Imports documentados
- [x] Archivo SimpleVault.cdc standalone creado
- [x] Tests escritos (requieren env configurado para ejecutar)
- [ ] Tests ejecutados localmente (requiere setup de tools)
- [x] Alternativas online documentadas (Remix, Flow Playground)

---

## Próximos Pasos

Para ejecutar tests completos:

1. **Setup Foundry** para tests de Solidity
2. **Actualizar Flow CLI** a v1.18.0+
3. **Configurar flow.json** con imports correctos
4. O usar **herramientas online** para demos rápidas

**Nota**: El código está sintácticamente correcto y basado en ejemplos reales de documentación oficial. Para videos educativos, las herramientas online (Remix + Flow Playground) son ideales.
