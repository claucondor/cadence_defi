# DeFi Patterns: EVM vs Cadence

> **Repositorio educativo** que compara patrones DeFi comunes en EVM/Solidity vs Cadence/Flow, mostrando problemas, workarounds, EIPs relacionados, y soluciones elegantes.

[![Flow](https://img.shields.io/badge/Flow-Blockchain-00ef8b)](https://flow.com/)
[![Cadence](https://img.shields.io/badge/Cadence-Language-00ef8b)](https://developers.flow.com/cadence)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-363636)](https://soliditylang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 🎯 ¿Qué es este proyecto?

Este repositorio documenta **17+ patrones DeFi comunes**, explicando:

1. 📖 **El problema teórico** en el contexto de DeFi
2. ⚠️ **Cómo se resolvió en EVM** (workarounds, limitaciones)
3. 📜 **EIPs propuestos** para solucionarlo
4. 🔧 **Patrones actuales** en Solidity (OpenZeppelin, etc.)
5. ✨ **Implementación en Cadence** (la forma elegante y segura)

### ¿Para quién es esto?

- 🎓 **Estudiantes** aprendiendo DeFi y blockchain
- 👨‍💻 **Desarrolladores** explorando Cadence vs Solidity
- 🎥 **Creadores de contenido** buscando material educativo
- 🔍 **Auditores** comparando paradigmas de seguridad
- 🏢 **Teams** evaluando Flow para sus proyectos

---

## 📚 Contenido

### [📖 Ver Índice Completo de Capítulos →](./INDEX.md)

**Capítulos destacados:**

- [x] [Capítulo 1: Reentrancy Attacks](./chapters/01-reentrancy/) - ✅ **Completo**
- [ ] Capítulo 2: Integer Overflow/Underflow
- [ ] Capítulo 3: ERC20 Approval Pattern
- [ ] Capítulo 5: Account Abstraction (EIP-4337)
- [ ] Capítulo 7: MEV & Sandwich Attacks
- [ ] Capítulo 9: AMM (Uniswap V2/V3)
- [ ] ... y más!

**Total**: 17 capítulos planificados | **Completados**: 1

---

## 🗂️ Estructura del Proyecto

```
cadence_defi/
├── INDEX.md                    # Índice maestro de todos los capítulos
├── README.md                   # Este archivo
├── chapters/                   # Capítulos organizados por patrón
│   ├── CHAPTER_TEMPLATE.md    # Template para nuevos capítulos
│   ├── 01-reentrancy/         # ✅ Capítulo completo
│   │   ├── README.md          # Documentación teórica
│   │   ├── evm/
│   │   │   ├── problema.sol   # Código vulnerable
│   │   │   └── workaround.sol # Soluciones en Solidity
│   │   ├── cadence/
│   │   │   ├── solucion.cdc   # Implementación en Cadence
│   │   │   └── tests/         # Tests
│   │   └── comparativa.md     # Comparación directa
│   ├── 02-overflow/           # 🔴 Pendiente
│   ├── 03-approval-pattern/   # 🔴 Pendiente
│   └── ...
├── contracts/                  # Contratos auxiliares
├── scripts/                    # Scripts de Flow
├── transactions/               # Transacciones de Flow
└── flow.json                   # Configuración de Flow
```

---

## 🚀 Inicio Rápido

### Requisitos Previos

```bash
# Flow CLI (para ejemplos de Cadence)
sh -ci "$(curl -fsSL https://storage.googleapis.com/flow-cli/install.sh)"

# Node.js (v16+) - opcional para ejemplos de Solidity
node --version

# Foundry - opcional para testing de Solidity
curl -L https://foundry.paradigm.xyz | bash
```

### Explorar un Capítulo

```bash
# Clonar el repositorio
git clone https://github.com/[tu-usuario]/cadence_defi
cd cadence_defi

# Ver el primer capítulo (Reentrancy)
cd chapters/01-reentrancy

# Leer la documentación
cat README.md

# Ver código EVM vulnerable
cat evm/problema.sol

# Ver código EVM con workarounds
cat evm/workaround.sol

# Ver solución en Cadence
cat cadence/solucion.cdc

# Probar código Cadence (requiere Flow CLI)
cd cadence
flow test
```

### Usar Flow Playground (Online)

No quieres instalar nada? Prueba los ejemplos en el navegador:

1. Ve a [Flow Playground](https://play.flow.com/)
2. Copia el código de `cadence/solucion.cdc`
3. Experimenta en tiempo real!

---

## 📖 Cómo Usar Este Repositorio

### Para Estudiantes

1. **Lee los capítulos en orden** (están diseñados para ser progresivos)
2. **Compara el código** de EVM vs Cadence lado a lado
3. **Ejecuta los ejemplos** para ver las diferencias en acción
4. **Lee las comparativas** para entender trade-offs

### Para Creadores de Contenido

Cada capítulo está diseñado para ser un **video/episodio** completo:

- 📝 **Script listo**: Cada README tiene estructura de video
- 💻 **Código funcional**: Demos que puedes grabar
- 📊 **Comparativas visuales**: Tablas y diagramas
- ⏱️ **Duración estimada**: 15-20 min por capítulo
- 🎯 **Objetivos claros**: Sección "¿Qué aprenderás?"

Ver [CHAPTER_TEMPLATE.md](./chapters/CHAPTER_TEMPLATE.md) para más detalles.

### Para Desarrolladores

- **Busca patrones específicos** en el [INDEX.md](./INDEX.md)
- **Compara implementaciones** directamente
- **Usa como referencia** al diseñar tus contratos
- **Contribuye** con nuevos patrones o mejoras

---

## 🎓 Ejemplo: Capítulo 1 - Reentrancy

### El Problema

En 2016, The DAO fue hackeado por $60M debido a un ataque de reentrancy. Este es **el bug más famoso** en la historia de Ethereum.

### Solución en Solidity

```solidity
// Requiere: ReentrancyGuard de OpenZeppelin
// Costo: ~2,500 gas extra
// Depende: Que el dev recuerde aplicarlo

contract Vault is ReentrancyGuard {
    function withdraw() public nonReentrant {
        uint256 balance = balances[msg.sender];
        balances[msg.sender] = 0;  // Orden correcto = crítico
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success);
    }
}
```

### Solución en Cadence

```cadence
// No requiere: Nada especial
// Costo: 0 gas extra
// Depende: Nada, el lenguaje te protege

pub fun withdraw(amount: UFix64): @Vault {
    pre { self.balance >= amount }
    self.balance = self.balance - amount
    return <- createVault(amount: amount)
}
```

**En Cadence, reentrancy es IMPOSIBLE** por diseño del lenguaje. Ver [capítulo completo →](./chapters/01-reentrancy/)

---

## 🔬 Investigación Realizada

Este proyecto está basado en investigación exhaustiva de:

- ✅ Papers académicos sobre vulnerabilidades en DeFi
- ✅ EIPs oficiales de Ethereum
- ✅ Documentación de OpenZeppelin, Uniswap, Aave, Compound
- ✅ Post-mortems de hacks históricos ($750M+ en pérdidas estudiadas)
- ✅ Documentación oficial de Cadence y Flow
- ✅ Comparativas de paradigmas de programación

**Fuentes principales**: Ver sección de "Recursos" en cada capítulo.

---

## 🤝 Contribuir

Las contribuciones son bienvenidas! Este es un proyecto educativo y comunitario.

### Formas de contribuir:

1. **Nuevos patrones**: Sugiere o implementa patrones adicionales
2. **Mejoras de código**: Optimiza ejemplos existentes
3. **Traducciones**: Ayuda a traducir capítulos
4. **Correcciones**: Typos, errores técnicos, etc.
5. **Feedback**: Abre issues con sugerencias

### Cómo contribuir:

```bash
# Fork el repositorio
git checkout -b feature/nuevo-patron

# Haz tus cambios
# Usa CHAPTER_TEMPLATE.md como guía

# Commit con mensaje descriptivo
git commit -m "Add Chapter 18: [Nombre del Patrón]"

# Push y abre PR
git push origin feature/nuevo-patron
```

---

## 📊 Estado del Proyecto

| Categoría | Capítulos | Completados | Progreso |
|-----------|-----------|-------------|----------|
| Seguridad Básica | 2 | 1 | 50% |
| Tokens y Aprobaciones | 2 | 0 | 0% |
| Account Abstraction | 1 | 0 | 0% |
| Contratos Actualizables | 1 | 0 | 0% |
| MEV y Composability | 2 | 0 | 0% |
| Protocolos DeFi Core | 2 | 0 | 0% |
| Access Control | 2 | 0 | 0% |
| Oráculos y Randomness | 2 | 0 | 0% |
| Gas y Payments | 2 | 0 | 0% |
| Tokens Especializados | 1 | 0 | 0% |
| **TOTAL** | **17** | **1** | **6%** |

**Última actualización**: 2025-11-14

---

## 📝 Licencia

MIT License - Ver [LICENSE](./LICENSE) para más detalles.

Este es un proyecto educativo. El código está disponible para aprender y experimentar.

---

## 🌟 Agradecimientos

- **Flow & Cadence Team** por crear un lenguaje más seguro
- **OpenZeppelin** por establecer estándares de seguridad en Solidity
- **La comunidad DeFi** por compartir post-mortems y aprendizajes
- **Todos los contribuidores** que ayuden a mejorar este recurso

---

## 📬 Contacto

- **Issues**: [GitHub Issues](https://github.com/[tu-usuario]/cadence_defi/issues)
- **Discussions**: [GitHub Discussions](https://github.com/[tu-usuario]/cadence_defi/discussions)
- **Twitter**: [@tu-handle](https://twitter.com/tu-handle)

---

## 🔗 Enlaces Útiles

### Flow & Cadence
- [Flow Developer Portal](https://developers.flow.com/)
- [Cadence Language Reference](https://developers.flow.com/cadence/language)
- [Flow Playground](https://play.flow.com/)
- [Flow Discord](https://discord.gg/flow)

### Ethereum & Solidity
- [Ethereum EIPs](https://eips.ethereum.org/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/)
- [Solidity Docs](https://docs.soliditylang.org/)
- [Smart Contract Security Best Practices](https://consensys.github.io/smart-contract-best-practices/)

### DeFi Education
- [DeFi MOOC](https://defi-learning.org/)
- [Uniswap Docs](https://docs.uniswap.org/)
- [Aave Docs](https://docs.aave.com/)

---

**⭐ Si este proyecto te resulta útil, dale una estrella!**

**🚀 Happy learning!**
