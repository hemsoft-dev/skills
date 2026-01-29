Here's the markdown table with the four additional columns:

| Research/Upgrade    | Tier | Progress | King Friday | King Saturday | King Sunday | King Monday |
| ------------------- | ---- | -------- | ----------- | ------------- | ----------- | ----------- |
| Motiv. Clucking     | 6    | 35/50    | Done        | Done          | Done        | Done        |
| Driver Training     | 6    | 30/30    | Done        | Done          | Done        | Done        |
| Shell Fortification | 6    | 60/60    | Done        | Done          | Done        | Done        |
|                     |      |          |             |               |             |             |
| Egg Loading Bots    | 7    | 1/2      | Done        | Done          | Done        | Done        |
| Super All. Frames   | 7    | 26/50    | Done        | Done          | Done        | Done        |
| Even Bigger Eggs    | 7    | 2/5      | Done        | Done          | Done        | Done        |
| Int Hatch Exp.      | 7    | 16/30    | Done        | Done          | Done        | Done        |
|                     |      |          |             |               |             |             |
| Quantum Egg St.     | 8    | 2/20     | Done        | Done          | Done        | Done        |
| Genetic Pur.        | 8    | 23/100   | Done        | Done          | Done        | Done        |
| ML Incubators       | 8    | 0/250    | Done        | Done          | Done        | Done        |
| Time Compression    | 8    | 5/20     | Done        | Done          | Done        | Done        |

- Egg of Curiosity: Unlocks and focuses on **Common Research**.
- Egg of Kindness: Lets you purchase and upgrade **Shipping/Vehicles**.
- Egg of Resilience: Grants the ability to buy and expand **Silos**.
- Egg of Integrity: Enables you to purchase and expand **Habitats**.
- Egg of Humility: Unlocks use of **Spaceships & Artifacts**.

| User                | King Friday       | King Saturday      | King Sunday        | King Monday        |
| ------------------- | ----------------- | ------------------ | ------------------ | ------------------ |
| Stats SE            | 123.38s (43/231)  | 1.848s (43/229)    | 1.613s (42/228)    | 722.960Q (45/218)  |
| Shifts              | 12 (12/7)         | 15 (12/7)          | 19 (12/7)          | 20 (12/7)          |
| Next Shift Costs    | 7.656Q            | 121.853q           | 123.028q           | 49.119q            |
| Hab Space           | 255,990,000       | 1,278,900,000      | 3,402,000,000      | 1,422,624,000      |
| Shipping Capacity/h | 15T               | 200T               | 358T               | 220T               |
| Egg Laying Rate/h   | 20T               | 111T               | 297T               | 124T               |
| Offline IHR         | 3,590,187         | 212,526            | 3,615,718          | 238,789            |
| Current Role        | Venda             | Wecca II           | Wecca II           | Wecca I            |
| Target Role TE      | Venda II = 231    | Wecca III = 207    | Wecca III = 231    | Wecca II = 175     |
| EB                  | 103.484d          | 1.281d             | 1.006d             | 179.172N           |
| Current TE Pending  | 43+4 (12/7)<br>47 | 43+12 (12/7)<br>55 | 42+24 (12/7)<br>66 | 45+13 (12/7)<br>58 |

# Humility Egg Spaceship Fuel Requirements

My notes: Use DEFIHENT EXTENDED you only need equal amounts of Black & Blue fuel (Curiosity (Research) & Kindness (Shipping))

So the distribution in the tank should be: Black 225T, Silver 50T maybe 0?, Blue 225T

This markdown file lists all 11 spaceship types and their fuel requirements for Short, Standard, and Extended missions.

|Spaceship|Short (Fuel)|Standard (Fuel)|Extended (Fuel)|
|---|---|---|---|
|Chicken One|5M Humility Egg|10M Humility Egg|20M Humility Egg|
|Chicken Nine|10M Humility Egg|20M Humility Egg|50M Humility Egg|
|Chicken Heavy|50M Humility Egg|100M Humility Egg|150M Humility Egg|
|BCR|10M Integrity Egg + 100M Humility Egg|20M Integrity Egg + 150M Humility Egg|30M Integrity Egg + 200M Humility Egg|
|Quintillion Chicken|10B Integrity Egg + 10B Humility Egg|20B Integrity Egg + 20B Humility Egg|50B Integrity Egg + 50B Humility Egg|
|Cornish-Hen Corvette|5B Integrity Egg + 20B Humility Egg|8B Integrity Egg + 40B Humility Egg|10B Integrity Egg + 70B Humility Egg|
|Galeggtica|200B Curiosity Egg + 200B Integrity Egg + 200B Humility Egg|400B Curiosity Egg + 400B Integrity Egg + 400B Humility Egg|600B Curiosity Egg + 600B Integrity Egg + 600B Humility Egg|
|Defihent|1T Curiosity Egg + 1T Humility Egg + 1T Kindness Egg|2T Curiosity Egg + 2T Humility Egg + 2T Kindness Egg|3T Curiosity Egg + 3T Humility Egg + 3T Kindness Egg|
|Voyegger|10T Curiosity Egg + 5T Humility Egg + 5T Kindness Egg|20T Curiosity Egg + 10T Humility Egg + 10T Kindness Egg|25T Curiosity Egg + 15T Humility Egg + 15T Kindness Egg|
|Henerprise|15T Curiosity Egg + 10T Humility Egg + 10T Kindness Egg|20T Curiosity Egg + 15T Humility Egg + 10T Resilience Egg + 15T Kindness Egg|25T Curiosity Egg + 25T Humility Egg + 20T Resilience Egg + 25T Kindness Egg|
|Atreggies Henliner|25T Curiosity Egg + 20T Humility Egg + 20T Kindness Egg|40T Curiosity Egg + 30T Humility Egg + 20T Resilience Egg + 30T Kindness Egg|50T Curiosity Egg + 75T Humility Egg + 40T Resilience Egg + 75T Kindness Egg|

## Missing Analyzers Worth Adding

| Analyzer                                       | Purpose                                                   | Why Add It                                                                                 |
| ---------------------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| **Microsoft.CodeAnalysis.NetAnalyzers**        | Built-in .NET analyzers (CA rules)                        | You get this via `AnalysisLevel=latest-all`, but explicitly adding ensures version control |
| **Meziantou.Analyzer**                         | Modern C# best practices, async patterns, string handling | Catches things SonarAnalyzer misses                                                        |
| **AsyncFixer**                                 | Async/await anti-patterns                                 | Critical for async-heavy code (which yours appears to be with AI agents)                   |
| **IDisposableAnalyzers**                       | IDisposable usage patterns                                | Important with Graph API/HTTP clients                                                      |
| **Microsoft.VisualStudio.Threading.Analyzers** | Threading/async correctness                               | Essential for agent code with async operations                                             |
| **Nullable.Extended.Analyzer**                 | Enhanced nullable reference type analysis                 | Since you have `Nullable=enable`                                                           |
| **ErrorProne.NET**                             | Common C# mistakes                                        | Google's error-prone patterns for .NET                                                     |

First quick-pass:
In folder 12 - please act on prompt-part1.md claude-opus-4.5 folder as your output. Only do the dotnet solution ignore the others.
In folder 12 - please act on prompt-part2.md claude-opus-4.5 folder as your output. Only do the dotnet solution ignore the others.

Full pass:
In folder 12 - please act on prompt-part1.md claude-opus-4.5 folder as your output.
In folder 12 - please act on prompt-part1.md gemini-3.0-pro folder as your output.
In folder 12 - please act on prompt-part1.md gpt-5.1 folder as your output.

In folder 12 - please act on prompt-part2.md claude-opus-4.5 folder as your output.
In folder 12 - please act on prompt-part2.md gemini-3.0-pro folder as your output.
In folder 12 - please act on prompt-part2.md gpt-5.1 folder as your output.

5354
189.4

 Wl&Aus@OwY024DRDXx
