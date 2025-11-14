# Capítulo XX: [Nombre del Patrón]

> **Duración estimada del video**: [15-20 minutos]
> **Dificultad**: [Principiante/Intermedio/Avanzado]
> **Prerequisitos**: [Lista de capítulos anteriores necesarios]

---

## 📋 Índice

1. [Introducción](#introducción)
2. [El Problema](#el-problema)
3. [Solución en EVM](#solución-en-evm)
4. [EIPs Relacionados](#eips-relacionados)
5. [Solución en Cadence](#solución-en-cadence)
6. [Comparación](#comparación)
7. [Demo Práctica](#demo-práctica)
8. [Recursos Adicionales](#recursos-adicionales)

---

## 🎯 Introducción

### ¿Qué aprenderás?

En este capítulo aprenderás:
- [ ] [Objetivo 1]
- [ ] [Objetivo 2]
- [ ] [Objetivo 3]

### Contexto

[Breve explicación del contexto histórico y por qué este patrón es importante]

---

## ❌ El Problema

### Descripción Teórica

[Explicación detallada del problema]

### Ejemplo del Mundo Real

[Casos históricos, hacks famosos, o situaciones donde esto causó problemas]

**Ejemplos notables:**
- **[Nombre del incidente]** (Año): $X millones perdidos
  - [Breve descripción]
  - [Lección aprendida]

### ¿Por qué es problemático en EVM?

[Explicación de las limitaciones técnicas de EVM que causan este problema]

**Limitaciones de EVM:**
1. [Limitación 1]
2. [Limitación 2]
3. [Limitación 3]

---

## 🔧 Solución en EVM

### Workarounds Actuales

#### Workaround 1: [Nombre]

**Descripción**: [Explicación]

**Ventajas**:
- ✅ [Ventaja 1]
- ✅ [Ventaja 2]

**Desventajas**:
- ❌ [Desventaja 1]
- ❌ [Desventaja 2]

**Código ejemplo**:
```solidity
// Ver: evm/workaround.sol
[Snippet relevante]
```

#### Workaround 2: [Nombre]

[Misma estructura]

### Librerías y Herramientas

**Más utilizadas:**
- **OpenZeppelin**: [Nombre del contrato]
- **[Otra librería]**: [Descripción]

---

## 📜 EIPs Relacionados

### EIP-XXXX: [Nombre del EIP]

- **Status**: [Draft/Review/Final/Living/Stagnant]
- **Autor**: [Nombre]
- **Creado**: [Fecha]
- **Descripción**: [Breve explicación]
- **Link**: [URL al EIP]

**¿Qué problema soluciona?**
[Explicación]

**¿Por qué no soluciona todo?**
[Limitaciones que aún existen]

### EIP-YYYY: [Otro EIP relacionado]

[Misma estructura]

---

## ✨ Solución en Cadence

### ¿Cómo Cadence resuelve esto nativamente?

[Explicación de las características del lenguaje que resuelven el problema]

**Ventajas clave de Cadence:**
1. **[Característica 1]**: [Explicación]
2. **[Característica 2]**: [Explicación]
3. **[Característica 3]**: [Explicación]

### Implementación

```cadence
// Ver: cadence/solucion.cdc
[Snippet relevante]
```

### ¿Por qué esto es mejor?

- ✅ **[Ventaja 1]**: [Explicación detallada]
- ✅ **[Ventaja 2]**: [Explicación detallada]
- ✅ **[Ventaja 3]**: [Explicación detallada]

---

## ⚖️ Comparación

| Aspecto | EVM (Solidity) | Cadence (Flow) |
|---------|----------------|----------------|
| **Complejidad** | [Descripción] | [Descripción] |
| **Seguridad** | [Descripción] | [Descripción] |
| **Gas/Costos** | [Descripción] | [Descripción] |
| **Developer Experience** | [Descripción] | [Descripción] |
| **Auditabilidad** | [Descripción] | [Descripción] |

### Tabla Resumen: Características del Patrón

| Característica | EVM | Cadence |
|----------------|-----|---------|
| Requiere librería externa | ❌ Sí | ✅ No (nativo) |
| Vulnerable por defecto | ❌ Sí | ✅ No |
| Fácil de auditar | ⚠️ Medio | ✅ Sí |
| [Otra característica] | [Status] | [Status] |

---

## 💻 Demo Práctica

### Setup

```bash
# Clonar el repositorio
git clone [URL]
cd cadence_defi/chapters/XX-nombre

# Para EVM
cd evm
# [Comandos específicos]

# Para Cadence
cd cadence
flow test
```

### Paso 1: Código Vulnerable (EVM)

```bash
# Correr el ejemplo vulnerable
[comandos]
```

**Salida esperada:**
```
[Output mostrando la vulnerabilidad]
```

### Paso 2: Workaround (EVM)

```bash
# Correr la solución con workaround
[comandos]
```

**Salida esperada:**
```
[Output mostrando que funciona pero con limitaciones]
```

### Paso 3: Solución Cadence

```bash
# Correr la implementación en Cadence
flow test
```

**Salida esperada:**
```
[Output mostrando la elegancia de la solución]
```

---

## 📚 Recursos Adicionales

### Documentación Oficial
- [Cadence Documentation](https://developers.flow.com/cadence)
- [EIP-XXXX Specification](URL)
- [Solidity Docs](URL específica)

### Artículos y Blogs
- [Título del artículo](URL) - [Autor, Fecha]
- [Título del artículo](URL) - [Autor, Fecha]

### Videos Recomendados
- [Título del video](URL) - [Canal, Duración]

### Papers Académicos
- [Título del paper](URL) - [Autores, Año]

### Código de Referencia
- [Proyecto Open Source](URL)
- [Implementación de producción](URL)

---

## 🎬 Guión para Video

### Introducción (2 min)
- Hook: [Frase llamativa o estadística impactante]
- Presentación del problema
- Preview de lo que veremos

### Desarrollo (12 min)
- **Parte 1**: El problema en detalle (3 min)
  - [Puntos clave a cubrir]
- **Parte 2**: Soluciones en EVM (4 min)
  - [Puntos clave a cubrir]
- **Parte 3**: Solución en Cadence (5 min)
  - [Puntos clave a cubrir]

### Demo (4 min)
- Mostrar código vulnerable
- Mostrar workaround
- Mostrar solución Cadence

### Conclusión (2 min)
- Recap de puntos clave
- Call to action
- Preview del próximo capítulo

---

## ✅ Checklist para el Video

Antes de grabar:
- [ ] README completado y revisado
- [ ] Código EVM funcional y comentado
- [ ] Código Cadence funcional y testeado
- [ ] Tests pasando correctamente
- [ ] Comparativa completa
- [ ] Referencias verificadas

Durante la grabación:
- [ ] Audio claro
- [ ] Código visible y con buen tamaño
- [ ] Ejemplos funcionando
- [ ] Transiciones suaves

Después de grabar:
- [ ] Edición completa
- [ ] Timestamps en descripción
- [ ] Links a código en GitHub
- [ ] Link al siguiente episodio

---

## 🤔 Preguntas Frecuentes

**P: [Pregunta común 1]**
R: [Respuesta]

**P: [Pregunta común 2]**
R: [Respuesta]

**P: [Pregunta común 3]**
R: [Respuesta]

---

## 🔗 Enlaces Rápidos

- [← Capítulo Anterior](../XX-nombre/)
- [↑ Índice General](../../INDEX.md)
- [→ Siguiente Capítulo](../XX-nombre/)

---

**Tags**: `#DeFi` `#Cadence` `#Solidity` `#[Patrón específico]` `#Blockchain`

**Fecha de creación**: YYYY-MM-DD
**Última actualización**: YYYY-MM-DD
**Estado**: 🔴 Pendiente / 🟡 En Progreso / 🟢 Completo
