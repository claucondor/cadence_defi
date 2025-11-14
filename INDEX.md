# DeFi Patterns: EVM vs Cadence

## Índice de Capítulos / Episodios

Este repositorio documenta patrones comunes de DeFi, explicando:
- El problema teórico
- Cómo se resolvió en EVM (workarounds y limitaciones)
- EIPs propuestos para solucionarlo
- Patrones actuales en Solidity
- **Implementación elegante en Cadence**

---

## 📚 Capítulos

### **Seguridad Básica**

#### Capítulo 1: Reentrancy Attacks
- **Problema**: Llamadas recursivas que permiten drenar fondos
- **EVM Workarounds**: Checks-Effects-Interactions pattern, ReentrancyGuard
- **Solución Cadence**: Resources elimina reentrancy por diseño
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/01-reentrancy/)

#### Capítulo 2: Integer Overflow/Underflow
- **Problema**: Aritmética sin límites causa vulnerabilidades
- **EVM Workarounds**: SafeMath library, Solidity 0.8+ built-in checks
- **Solución Cadence**: Prevención nativa de overflow/underflow
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/02-overflow/)

---

### **Patrones de Tokens y Aprobaciones**

#### Capítulo 3: ERC20 Approval Pattern Problems
- **Problema**: Two-step approval, infinite approvals, SWC-114 multiple withdrawal attack
- **EVM Workarounds**: Permit (EIP-2612), Permit2, ERC-7674
- **EIPs Relacionados**: EIP-2612, EIP-3009, ERC-7674
- **Solución Cadence**: Capabilities para control granular sin approvals
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/03-approval-pattern/)

#### Capítulo 4: NFT Standards Evolution
- **Problema**: ERC-721 gas costs, lack of batch operations
- **EVM Workarounds**: ERC-1155 multi-token standard
- **EIPs Relacionados**: ERC-721, ERC-1155, ERC-998
- **Solución Cadence**: NFT Resources con ownership nativo
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/04-nft-standards/)

---

### **Account Abstraction & Wallets**

#### Capítulo 5: Account Abstraction
- **Problema**: EOA dependency, limited wallet functionality
- **EVM Workarounds**: EIP-4337 UserOperations, alt mempool
- **EIPs Relacionados**: EIP-4337, EIP-7702
- **Solución Cadence**: Native account model with built-in capabilities
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/05-account-abstraction/)

---

### **Contratos Actualizables**

#### Capítulo 6: Upgradeable Contracts
- **Problema**: Smart contracts immutability vs need for upgrades
- **EVM Workarounds**: Proxy patterns (Transparent, UUPS, Diamond)
- **EIPs Relacionados**: EIP-1967, EIP-1822 (UUPS), EIP-2535 (Diamond)
- **Solución Cadence**: Contract upgrade mechanisms
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/06-upgradeable-contracts/)

---

### **MEV y Composability**

#### Capítulo 7: MEV & Sandwich Attacks
- **Problema**: Public mempool permite frontrunning y sandwich attacks
- **EVM Workarounds**: Private RPCs, Flashbots, slippage protection
- **Solución Cadence**: Transaction privacy improvements
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/07-mev-sandwich/)

#### Capítulo 8: Flash Loans
- **Problema**: Uncollateralized loans usados para manipulación
- **EVM Workarounds**: TWAP oracles, circuit breakers
- **Solución Cadence**: Resource-based protection mechanisms
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/08-flash-loans/)

---

### **Protocolos DeFi Core**

#### Capítulo 9: AMM - Automated Market Makers
- **Problema**: Capital efficiency in constant product formula (x*y=k)
- **Evolución**: Uniswap V2 → V3 (concentrated liquidity)
- **Solución Cadence**: Resource-based liquidity pools
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/09-amm/)

#### Capítulo 10: Lending Protocols
- **Problema**: Interest rate models, collateralization, liquidations
- **Ejemplos**: Compound, Aave utilization-based rates
- **Solución Cadence**: Resource-based lending with built-in safety
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/10-lending/)

---

### **Access Control & Governance**

#### Capítulo 11: Access Control Patterns
- **Problema**: msg.sender vulnerabilities, centralization
- **EVM Workarounds**: Ownable, RBAC, AccessControl
- **Solución Cadence**: Capability-based access control
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/11-access-control/)

#### Capítulo 12: Timelock & Governance
- **Problema**: Governance attacks, malicious proposals
- **EVM Workarounds**: TimelockController, Governor contracts
- **Solución Cadence**: Native governance with resources
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/12-governance/)

---

### **Oráculos y Randomness**

#### Capítulo 13: Oracle Problem
- **Problema**: On-chain contracts can't access off-chain data
- **EVM Workarounds**: Chainlink, Band Protocol, multiple oracle sources
- **Solución Cadence**: Oracle integration patterns
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/13-oracles/)

#### Capítulo 14: Randomness & Commit-Reveal
- **Problema**: Deterministic blockchain can't generate true randomness
- **EVM Workarounds**: Chainlink VRF, commit-reveal schemes
- **Solución Cadence**: Native VRF with commit-reveal pattern
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/14-randomness/)

---

### **Gas Optimization & Payment Patterns**

#### Capítulo 15: Pull over Push Payments
- **Problema**: Push payments fail silently, gas griefing
- **EVM Workarounds**: Withdrawal pattern, mapping-based balances
- **Solución Cadence**: Resource-based payment handling
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/15-pull-payments/)

#### Capítulo 16: Gas Optimization Patterns
- **Problema**: High gas costs in EVM storage and computation
- **EVM Workarounds**: Storage packing, off-chain computation, L2s
- **Solución Cadence**: Efficient resource model
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/16-gas-optimization/)

---

### **Tokens Especializados**

#### Capítulo 17: Yield-Bearing Tokens
- **Problema**: Standardization of vault tokens
- **EVM Workarounds**: ERC-4626, ERC-5115
- **EIPs Relacionados**: ERC-4626, ERC-5115
- **Solución Cadence**: Resource-based yield vaults
- **Status**: 🔴 Pendiente
- [📁 Ver capítulo](./chapters/17-yield-tokens/)

---

## 🎯 Estructura de cada Capítulo

Cada capítulo contiene:

```
chapters/XX-nombre/
├── README.md              # Documentación teórica completa
├── evm/
│   ├── problema.sol       # Código vulnerable en Solidity
│   ├── workaround.sol     # Solución actual con workarounds
│   └── explicacion.md     # Explicación de limitaciones
├── cadence/
│   ├── solucion.cdc       # Implementación en Cadence
│   ├── tests/             # Tests en Cadence
│   └── explicacion.md     # Por qué Cadence lo hace mejor
└── comparativa.md         # Comparación directa EVM vs Cadence
```

---

## 🚀 Cómo usar este repositorio

### Para estudiantes:
1. Sigue los capítulos en orden
2. Lee el README.md de cada capítulo
3. Compara el código de EVM vs Cadence
4. Ejecuta los tests

### Para creadores de contenido:
- Cada capítulo = 1 video/episodio
- Documentación lista para usar
- Código funcional para demos
- Referencias a EIPs y resources

---

## 📖 Referencias

### Documentación
- [Flow & Cadence Docs](https://developers.flow.com/)
- [Ethereum EIPs](https://eips.ethereum.org/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/)
- [Solidity Patterns](https://fravoll.github.io/solidity-patterns/)

### Papers y Artículos
- [Flash Boys 2.0: Frontrunning in DEXes](https://arxiv.org/abs/1904.05234)
- [DeFi Protocols for Loanable Funds](https://arxiv.org/abs/2006.13922)
- [Resource-Oriented Programming](https://medium.com/dapperlabs/resource-oriented-programming-bee4d69c8f8e)

---

## 🤝 Contribuciones

Este es un proyecto educativo. Las contribuciones son bienvenidas:
- Nuevos patrones
- Mejoras en explicaciones
- Correcciones de código
- Traducciones

---

## 📝 Licencia

MIT License - Ver LICENSE para más detalles

---

**Última actualización**: 2025-11-14
**Total de Capítulos**: 17
**Status del Proyecto**: 🚧 En desarrollo inicial
