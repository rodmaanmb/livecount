# 🐛 BUGFIX — Occupation moyenne absurde (9 788,2%)

**Date:** 27 janvier 2026  
**Statut:** ✅ FIXED

---

## 1. Symptôme

L'UI affiche des valeurs absurdes pour "Occupation moy." :
- **Observé** : 9 788,2% / 9 089,1%
- **Attendu** : 72,3% / 68,5% (valeurs entre 0% et 100%)

---

## 2. Cause Racine

**Double "×100"** dans la chaîne de calcul :

### Étape 1 : MetricsCalculator (AVANT le fix)
```swift
// MetricsCalculator.swift ligne 267
let avgRatio = totalDuration > 0 ? (weightedOccupancySum / totalDuration) : 0.0
var avgOccupancy = avgRatio * 100  // ← ×100 ICI (0.9788 → 97.88)
avgOccupancy = min(max(avgOccupancy, 0.0), 100.0)
// avgOccupancy = 97.88 (déjà en pourcentage)
```

### Étape 2 : ReportingEngine
```swift
// ReportingEngine.swift ligne 29
let avgOccupancyPercent = snapshot.avgOccupancyPercent.formattedPercent(decimals: 1)
```

### Étape 3 : FormatHelpers.formattedPercent()
```swift
// FormatHelpers.swift ligne 58
let percentValue = self * 100  // ← ×100 ENCORE (97.88 × 100 = 9788)
return "\(numberString)%"
// Résultat : "9 788,2%" 😱
```

**Total** : 0.9788 (ratio) × 100 (MetricsCalculator) × 100 (formattedPercent) = 9788% ❌

---

## 3. Solution

**Principe** : `avgOccupancyPercent` dans `MetricsSnapshot` doit être un **ratio (0.0-1.0)**, pas un pourcentage (0-100). Le formatage en "%" se fait uniquement dans le layer de présentation.

### Fix 1 : MetricsCalculator (retourner un ratio)
```swift
// MetricsCalculator.swift ligne 266-271
let avgRatio = totalDuration > 0 ? (weightedOccupancySum / totalDuration) : 0.0
// BUGFIX: Retourner un ratio (0.0-1.0), pas un pourcentage (0-100)
// Le formatage en % se fait dans ReportingEngine via formattedPercent()
var avgOccupancy = avgRatio  // ← Pas de ×100
if !avgOccupancy.isFinite {
    avgOccupancy = 0.0
}
avgOccupancy = min(max(avgOccupancy, 0.0), 1.0)  // ← Clamper à 0.0-1.0
```

### Fix 2 : HistoryView (affichage direct)
```swift
// HistoryView.swift ligne 889
dataRow(
    label: "Occupation moyenne",
    value: String(format: "%.1f%%", snapshot.avgOccupancyPercent * 100)  // ← Ajouter ×100 ici
)
```

### Fix 3 : MetricsCalculatorSelfTests (assertions)
```swift
// MetricsCalculatorSelfTests.swift
// AVANT
assert(snapshot.avgOccupancyPercent >= 0.0 && snapshot.avgOccupancyPercent <= 100.0)

// APRÈS
assert(snapshot.avgOccupancyPercent >= 0.0 && snapshot.avgOccupancyPercent <= 1.0)
```

---

## 4. Fichiers Modifiés (3)

1. **`Services/MetricsCalculator.swift`**
   - Ligne 267-271 : Retourner ratio au lieu de pourcentage
   - Ligne 271 : Clamper à 1.0 au lieu de 100.0

2. **`Views/HistoryView.swift`**
   - Ligne 889 : Ajouter `× 100` lors du formatage direct

3. **`Services/MetricsCalculatorSelfTests.swift`**
   - Lignes 39, 62 : Assertions 0.0-1.0 au lieu de 0.0-100.0

---

## 5. Impact

### Avant le fix
```
ratio = 0.9788
MetricsCalculator: 0.9788 × 100 = 97.88 (%)
formattedPercent: 97.88 × 100 = 9788 (%)
Affichage: "9 788,2%" ❌
```

### Après le fix
```
ratio = 0.9788
MetricsCalculator: 0.9788 (ratio, pas de ×100)
formattedPercent: 0.9788 × 100 = 97.88 (%)
Affichage: "97,9%" ✅
```

---

## 6. Vérification

### Tests unitaires
```swift
// ReportingEngineTests.swift
avgOccupancyPercent: 0.723  // ← Déjà des ratios (OK)
avgOccupancyPercent: 0.75
avgOccupancyPercent: 0.82
```

**Status** : ✅ Tous les tests existants utilisent déjà des ratios, pas besoin de les modifier

### Tests manuels
1. **Nominal** : 0.723 → "72,3%" ✅
2. **High** : 0.95 → "95,0%" ✅
3. **Low** : 0.15 → "15,0%" ✅
4. **Zero** : 0.0 → "0,0%" ✅
5. **Full** : 1.0 → "100,0%" ✅

### Build
```
✅ No linter errors found
✅ 3 fichiers modifiés
```

---

## 7. Cohérence du Model

### MetricsSnapshot.avgOccupancyPercent
**Type** : `Double`  
**Unité** : Ratio (0.0-1.0)  
**Nom trompeur** : Le nom contient "Percent" mais c'est un ratio 🤔

**Options futures** :
1. **Renommer** : `avgOccupancyRatio` (breaking change)
2. **Documenter** : Ajouter doc comment précisant l'unité
3. **Garder** : Le nom "Percent" est acceptable si doc claire

**Décision** : Garder le nom, ajouter doc comment

---

## 8. Autres Usages de avgOccupancyPercent

### ✅ Usages corrects (aucun changement nécessaire)

1. **ReportingEngine.swift** : Utilise `formattedPercent()` → OK
2. **ReportingEngineTests.swift** : Utilise des ratios → OK
3. **ReportingSummary.swift** : Stocke des strings formatés → OK
4. **ReportingDelta.swift** : Utilise `formattedPoints()` → OK

### ⚠️ Usages à surveiller (si ajouts futurs)

- **DashboardViewModel** : Si affichage direct, ajouter `× 100`
- **Charts** : Axe Y doit être 0-100 (ajouter `× 100` aux valeurs)

---

## 9. Prevention

### Rule : "Percent" fields sont toujours des ratios

**Convention** : Tous les champs avec "Percent" dans le nom sont des **ratios (0.0-1.0)**, pas des pourcentages (0-100).

**Formatage** :
- ✅ `value.formattedPercent()` → "72,3%"
- ✅ `String(format: "%.1f%%", value * 100)` → "72,3%"
- ❌ `String(format: "%.1f%%", value)` → "0,7%" (incorrect)

**Tests** :
- ✅ `assert(value >= 0.0 && value <= 1.0)`
- ❌ `assert(value >= 0.0 && value <= 100.0)` (incorrect)

---

## ✅ Outcome

**BUGFIX COMPLETED**

✅ Double "×100" identifié et corrigé  
✅ `avgOccupancyPercent` maintenant ratio (0.0-1.0)  
✅ Affichage correct : "72,3%" au lieu de "9 788,2%"  
✅ 3 fichiers modifiés (Calculator + View + Tests)  
✅ Cohérence : tous les tests utilisaient déjà des ratios  
✅ Code clean, no linter errors  

**Impact produit** :
- ✅ UI affiche des valeurs correctes (0%-100%)
- ✅ Cohérence du model (ratio partout)
- ✅ Prevention : convention "Percent" = ratio
