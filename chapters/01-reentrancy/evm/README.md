# Reentrancy Tests - Solidity (Foundry)

Este directorio contiene tests profesionales usando **Foundry** para demostrar:
1. El ataque de reentrancy funciona en código vulnerable
2. Las tres soluciones principales previenen el ataque

## 🚀 Setup Rápido

### Requisitos Previos

```bash
# Instalar Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verificar instalación
forge --version
```

### Instalación

```bash
# Desde el directorio cadence_defi/chapters/01-reentrancy/evm
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts

# Compilar contratos
forge build
```

## 🧪 Ejecutar Tests

### Todos los tests

```bash
forge test -vv
```

### Solo tests del exploit

```bash
forge test --match-contract ReentrancyExploitTest -vvv
```

### Solo tests de protección

```bash
forge test --match-contract ReentrancyProtectionTest -vvv
```

### Con gas report

```bash
forge test --gas-report
```

### Con coverage

```bash
forge coverage
```

## 📊 Tests Incluidos

### ReentrancyExploit.t.sol

Tests que demuestran que el exploit **funciona** en código vulnerable:

- ✅ `test_ReentrancyExploitDrainsVault()` - Demuestra que el ataque drena el vault
- ✅ `test_HonestUsersLoseTheirMoney()` - Usuarios honestos pierden fondos
- ✅ `test_MultipleVictims()` - Un atacante puede robar de múltiples usuarios
- ✅ `test_DetailedAttackAnalysis()` - Análisis paso a paso del ataque

**Resultado esperado**: Todos los tests pasan (el exploit funciona)

### ReentrancyProtection.t.sol

Tests que demuestran que las soluciones **previenen** el ataque:

#### CEI Pattern
- ✅ `test_CEI_PreventsReentrancy()` - Actualizar estado primero previene el ataque

#### ReentrancyGuard
- ✅ `test_Guard_PreventsReentrancy()` - Mutex lock previene re-entrada
- ✅ `test_Guard_GasOverhead()` - Mide overhead de gas (~2,500)

#### Pull Payment
- ✅ `test_Pull_PreventsReentrancy()` - Separación de lógica previene ataque
- ✅ `test_Pull_RequiresTwoTransactions()` - Demuestra proceso de 2 pasos

#### Comparación
- ✅ `test_CompareAllThreeSolutions()` - Compara las 3 soluciones lado a lado

**Resultado esperado**: Todos los tests pasan (las soluciones funcionan)

## 📈 Ejemplo de Output

```bash
$ forge test -vv

Running 15 tests for test/ReentrancyExploit.t.sol:ReentrancyExploitTest
[PASS] test_ReentrancyExploitDrainsVault() (gas: 156789)
[PASS] test_HonestUsersLoseTheirMoney() (gas: 182456)
[PASS] test_MultipleVictims() (gas: 245123)
...

Running 12 tests for test/ReentrancyProtection.t.sol:ReentrancyProtectionTest
[PASS] test_CEI_PreventsReentrancy() (gas: 145678)
[PASS] test_Guard_PreventsReentrancy() (gas: 148234)
[PASS] test_Pull_PreventsReentrancy() (gas: 152890)
...

Test result: ok. 27 tests passed; 0 failed; finished in 5.23s
```

## 🔍 Análisis Detallado

### Ver logs de console

```bash
forge test --match-test test_DetailedAttackAnalysis -vvvv
```

Output esperado:
```
=== ATTACK ANALYSIS ===
Vault balance before attack: 3000000000000000000
Vault balance after attack: 0
Alice's recorded balance: 3000000000000000000
Attacker's recorded balance: 0

ETH stolen: 3000000000000000000
```

### Gas Report Detallado

```bash
forge test --gas-report
```

Output esperado:
```
| Contract                | Method     | Gas    |
|-------------------------|------------|--------|
| VulnerableVault         | withdraw   | 45678  |
| CEIVault                | withdraw   | 45890  |
| GuardedVault            | withdraw   | 48234  | +2,500 gas
| PullPaymentVault        | completeWd | 47123  |
```

## 🎯 Para Videos/Demos

### Demo del Exploit

```bash
# Mostrar que el exploit funciona
forge test --match-test test_ReentrancyExploitDrainsVault -vvvv
```

Explica:
1. Usuarios honestos depositan 5 ETH cada uno
2. Atacante deposita solo 1 ETH
3. Atacante drena TODO el vault (incluyendo los 10 ETH honestos)
4. Vault queda en 0 ETH

### Demo de las Soluciones

```bash
# Mostrar que las soluciones funcionan
forge test --match-test test_CEI_PreventsReentrancy -vvvv
forge test --match-test test_Guard_PreventsReentrancy -vvvv
forge test --match-test test_Pull_PreventsReentrancy -vvvv
```

Explica:
- CEI: Orden correcto previene el ataque
- Guard: Mutex lock hace revert
- Pull: Separación de lógica protege

### Comparación de Gas

```bash
forge test --match-test test_CompareAllThreeSolutions -vvv
```

## 📁 Estructura de Archivos

```
evm/
├── foundry.toml           # Configuración de Foundry
├── remappings.txt         # Imports de librerías
├── README.md              # Este archivo
│
├── problema.sol           # Código vulnerable
├── workaround.sol         # Tres soluciones
│
├── test/
│   ├── ReentrancyExploit.t.sol      # Tests del exploit
│   └── ReentrancyProtection.t.sol   # Tests de soluciones
│
└── lib/                   # Dependencias (instaladas por forge)
    ├── forge-std/
    └── openzeppelin-contracts/
```

## 🐛 Troubleshooting

### Error: "forge: command not found"

```bash
# Re-instalar Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Error: "Could not find forge-std"

```bash
# Instalar dependencias
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts
```

### Tests fallan

```bash
# Limpiar y recompilar
forge clean
forge build
forge test
```

## 📚 Recursos

- [Foundry Book](https://book.getfoundry.sh/)
- [Foundry Cheatsheet](https://github.com/dabit3/foundry-cheatsheet)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)

## 🎓 Lecciones

### Del Exploit
- ✅ El ataque de reentrancy es trivial de ejecutar
- ✅ Un atacante puede drenar TODO el vault
- ✅ Múltiples víctimas pierden fondos simultáneamente
- ✅ El código "se ve bien" pero es vulnerable

### De las Soluciones
- ✅ CEI Pattern: Efectivo pero fácil de olvidar
- ✅ ReentrancyGuard: Explícito pero con overhead de gas
- ✅ Pull Payment: Seguro pero peor UX
- ⚠️ Todas requieren que el desarrollador las aplique manualmente

### Comparación con Cadence
- ❌ En Solidity: Vulnerable por defecto, protección manual
- ✅ En Cadence: Seguro por defecto, protección automática

Ver `../cadence/` para la implementación en Cadence donde este problema NO EXISTE.
