# LLM Registry

Last Updated: 2025-12-24

## Model Selection Guide

### By Use Case

- **Agentic Coding**: Gemini 3 Flash, Kimi K2, Grok Code Fast 1, GLM 4.7
- **Complex Reasoning**: Claude Opus 4.5, Gemini 3 Pro, Grok 4
- **High-Volume/Low-Cost**: GLM 4.7, Kimi K2, Claude Haiku 4.5
- **Multimodal Analysis**: Gemini 3 Pro/Flash (text/image/audio/video)
- **Long Context (1M+)**: Claude Sonnet 4.5, Gemini 3 Pro/Flash
- **Scientific Research**: Gemini 3 Pro (GPQA Diamond leader)

---

## GitHub Copilot Hosted Models

| Model | Reference | Multiplier | Context | Modalities | Performance | Best For |
|-------|-----------|------------|---------|------------|-------------|----------|
| Claude Opus 4.5 | anthropic/claude-opus-4.5 | 3x | 200K | Text, Vision | 24 tok/s, 4.7s latency | Complex SE, multi-agent orchestration |
| Claude Sonnet 4.5 | anthropic/claude-sonnet-4.5 | 1x | 1M | Text, Vision | 48-68 tok/s | Production coding, security analysis |
| Claude Haiku 4.5 | anthropic/claude-haiku-4.5 | 0.33x | 200K | Text, Vision | 129 tok/s, 0.7s latency | Real-time chat, high-volume tasks |
| Gemini 3 Pro (Preview) | google/gemini-3-pro-preview | 1x | 1.05M | Text, Vision, Audio, Video | 76-82 tok/s, 3.4s latency | Frontier reasoning, research synthesis |
| Gemini 3 Flash (Preview) | google/gemini-3-flash-preview | 0.33x | 1.05M | Text, Vision, Audio, Video | 75-123 tok/s, 0.85s latency | Fast agentic loops, interactive dev |
| GPT-5.2 | openai/gpt-5.2 | 1x | 400K | Text | Adaptive reasoning | Math, science, tool orchestration |
| Grok Code Fast 1 | x-ai/grok-code-fast-1 | 0x | 256K | Text | 89 tok/s, visible thinking | Agentic coding, rapid iteration |
| Raptor mini (Preview) | raptor-mini | 0x | TBD | Text | Preview | TBD |

---

## Detailed Model Profiles

### Anthropic Models

#### Claude Opus 4.5

**The Frontier Reasoning Powerhouse**

| Spec | Value |
|------|-------|
| Context | 200K tokens |
| Cost | $5 / $25 per 1M tokens |
| Throughput | 24 tok/s |
| Latency | 4.7s |
| Modalities | Text, Vision |

**Capabilities:**

- Frontier reasoning model optimized for complex software engineering and agentic workflows
- Handles long-horizon tasks requiring extensive planning and execution
- Extended thinking capability for deep problem decomposition
- Superior performance on autonomous research and debugging
- Best-in-class multi-agent orchestration for parallel workstreams
- Excels at security research and vulnerability analysis

**Best For:** Complex software engineering, autonomous agents, multi-agent coordination, security research, long-running tasks requiring strategic planning

**Avoid For:** High-volume/low-latency needs, cost-sensitive applications, simple tasks

---

#### Claude Sonnet 4.5

**The Production Coding Champion**

| Spec | Value |
|------|-------|
| Context | 1M tokens |
| Cost | $3 / $15 per 1M tokens |
| Throughput | 48-68 tok/s |
| Latency | 1.1-2.3s |
| Modalities | Text, Vision |

**Capabilities:**

- State-of-the-art performance on SWE-bench Verified (coding benchmarks)
- 1M token context window for massive codebases and documentation
- Improved agentic capabilities with sophisticated tool orchestration
- Extended thinking for multi-step problem solving
- Trained to produce self-correcting, production-ready code
- Strong security analysis and code review capabilities

**Benchmarks:**

- SWE-bench Verified: State-of-the-art
- Coding benchmarks: Top performer

**Best For:** Production coding workflows, code review, security analysis, large codebase navigation, long-running agent tasks

**Avoid For:** Extremely cost-sensitive applications, tasks where Haiku suffices

---

#### Claude Haiku 4.5

**The Speed Demon**

| Spec | Value |
|------|-------|
| Context | 200K tokens |
| Cost | $1 / $5 per 1M tokens |
| Throughput | 129 tok/s |
| Latency | 0.7s |
| Modalities | Text, Vision |

**Capabilities:**

- Fastest and most efficient model in Anthropic's lineup
- >73% on SWE-bench Verified (approaches Sonnet 4 performance)
- Near-instant responses for real-time applications
- Extended thinking capability for complex reasoning
- Excellent for high-volume automation and chat interfaces
- Computer use (beta) and MCP tool support

**Performance Metrics:**

- Throughput: 129 tokens/second (fastest Claude)
- Latency: 0.7s TTFT
- SWE-bench: >73%

**Best For:** Real-time chat, high-volume applications, cost-sensitive deployments, rapid prototyping, latency-critical workflows

**Avoid For:** Tasks requiring maximum reasoning depth, very large context needs

---

### Google Models

#### Gemini 3 Pro Preview

**The Multimodal Frontier Leader**

| Spec | Value |
|------|-------|
| Context | 1.05M tokens |
| Cost | $2 / $12 per 1M tokens |
| Throughput | 76-82 tok/s |
| Latency | 3.3-3.9s |
| Modalities | Text, Vision, Audio, Video |

**Capabilities:**

- Flagship frontier model for high-precision multimodal reasoning
- Leads LMArena leaderboard for human preference alignment
- GPQA Diamond leader for scientific reasoning
- Strong on MathArena Apex, MMMU-Pro, Video-MMMU
- Built-in thinking capabilities with configurable reasoning levels
- Robust tool-calling and long-horizon planning stability
- Excels at SWE-Bench Verified and Terminal-Bench 2.0

**Key Strengths:**

- True multimodal: processes text, images, audio, video, and PDFs natively
- Infers intent with minimal prompting
- Superior zero-shot generation for complex UI and visualization
- Research synthesis and structured long-form content

**Best For:** Autonomous agents, scientific reasoning, multimodal analytics, research synthesis, high-context information processing, coding assistants

**Avoid For:** Ultra-low latency needs, budget-constrained simple tasks

---

#### Gemini 3 Flash Preview

**The Fast Multimodal Workhorse**

| Spec | Value |
|------|-------|
| Context | 1.05M tokens |
| Cost | $0.50 / $3 per 1M tokens |
| Throughput | 75-123 tok/s |
| Latency | 0.85-1.4s |
| Modalities | Text, Vision, Audio, Video |

**Capabilities:**

- High-speed thinking model with near-Pro level reasoning
- Substantially lower latency than larger Gemini variants
- Broad quality improvements over Gemini 2.5 Flash in reasoning, multimodal, and reliability
- Configurable thinking levels (minimal, low, medium, high)
- Automatic context caching for efficiency
- Strong tool use performance for agentic workflows

**Performance Metrics:**

- Throughput: 75-123 tokens/second
- Latency: 0.85s TTFT (via AI Studio)
- E2E Latency: 2.8-4.1s

**Best For:** Interactive development, long-running agent loops, collaborative coding, multi-turn chat, cost-efficient multimodal processing

**Avoid For:** Tasks requiring absolute maximum reasoning (use Pro), text-only simple tasks where cheaper options exist

---

### OpenAI Models

#### GPT-5.2

**The Adaptive Reasoner**

| Spec | Value |
|------|-------|
| Context | 400K tokens |
| Cost | $1.75 / $14 per 1M tokens |
| Throughput | Variable (adaptive) |
| Modalities | Text |

**Capabilities:**

- Latest in the GPT-5 series with adaptive reasoning
- Dynamically allocates computation based on task complexity
- Enhanced agentic and long-context performance over GPT-4o
- Strong improvements in math, coding, and scientific reasoning
- Optimized for tool calling and multi-step workflows
- Better instruction following and nuanced responses

**Best For:** Mathematical reasoning, scientific analysis, coding tasks, tool orchestration, tasks benefiting from adaptive compute allocation

**Avoid For:** Multimodal tasks (text-only), extreme budget constraints

---

### xAI Models

#### Grok 4

**The Premium Reasoner**

| Spec | Value |
|------|-------|
| Context | 256K tokens |
| Cost | $3 / $15 per 1M tokens (≤128K) |
| Throughput | 72-95 tok/s |
| Latency | 2.9s |
| Modalities | Text, Vision |

**Capabilities:**

- Latest reasoning model from xAI
- Parallel tool calling for complex agentic workflows
- 256K context window for large document processing
- Strong performance on complex reasoning benchmarks
- Vision capabilities for multimodal analysis

**Best For:** Complex reasoning tasks, parallel tool execution, large document analysis, multimodal reasoning

**Avoid For:** High-volume cost-sensitive applications, latency-critical chat

---

#### Grok Code Fast 1

**The Budget Speed Coder**

| Spec | Value |
|------|-------|
| Context | 256K tokens |
| Cost | $0.20 / $1.50 per 1M tokens |
| Throughput | 89 tok/s |
| Latency | 3.1s |
| Modalities | Text |

**Capabilities:**

- Speedy and economical reasoning model optimized for agentic coding
- Visible reasoning traces for debugging and understanding
- Strong at agent-driven file manipulation and code generation
- Excellent cost-performance ratio for coding workflows
- 256K context for large codebases

**Performance Metrics:**

- Throughput: 89 tokens/second
- Latency: 3.1s TTFT
- Cost: One of the cheapest capable coding models

**Best For:** Agentic coding workflows, rapid iteration, budget-conscious development, visible reasoning debugging

**Avoid For:** Non-coding tasks, tasks requiring premium reasoning depth

---

### MoonshotAI Models

#### Kimi K2

**The Trillion-Parameter MoE Beast**

| Spec | Value |
|------|-------|
| Context | 128K tokens |
| Cost | $0.456 / $1.84 per 1M tokens |
| Throughput | Variable |
| Modalities | Text |

**Capabilities:**

- 1 trillion total parameters with 32B active per forward pass (MoE architecture)
- Excels at coding (LiveCodeBench, SWE-bench), reasoning (ZebraLogic, GPQA), and tool-use (Tau2, AceBench)
- Optimized for agentic tool orchestration
- Strong code synthesis and multi-step reasoning
- Open-weights model available on HuggingFace

**Architecture:**

- Total Parameters: 1 trillion
- Active Parameters: 32B (MoE)
- Context: 128K tokens

**Best For:** Agentic tool use, code generation, reasoning tasks, cost-effective powerful inference

**Avoid For:** Very long context needs (>128K), multimodal tasks

---

#### Kimi K2 Thinking

**The Extended Reasoning Specialist**

| Spec | Value |
|------|-------|
| Context | 256K tokens |
| Cost | $0.40 / $1.75 per 1M tokens |
| Throughput | Variable |
| Modalities | Text |

**Capabilities:**

- Extended reasoning variant of Kimi K2
- 256K token context window (double K2)
- Stable operation with 200-300+ tool calls in single sessions
- Sets new open-source benchmarks on HLE, BrowseComp, SWE-Multilingual
- Optimized for long-horizon agentic workflows
- Chain-of-thought reasoning visible in output

**Key Differentiator:**

- Handles complex multi-step agent tasks with hundreds of tool invocations
- Best value for extended reasoning workflows

**Best For:** Long-horizon reasoning, complex agentic tasks with many tool calls, extended context workflows

**Avoid For:** Simple tasks, latency-critical chat applications

---

### Z.AI Models

#### GLM 4.7

**The Value-Packed Coder**

| Spec | Value |
|------|-------|
| Context | 203K tokens |
| Cost | $0.40 / $1.50 per 1M tokens |
| Throughput | 48-61 tok/s |
| Latency | 0.88-1.5s |
| Modalities | Text |

**Capabilities:**

- Latest flagship from Z.AI (Zhipu/Tsinghua)
- Enhanced programming capabilities over GLM 4.6
- More stable multi-step reasoning and execution
- Significant improvements in complex agent task execution
- More natural conversational experiences
- Superior front-end code aesthetics
- Open weights available on HuggingFace
- Built-in reasoning mode support

**Performance Metrics:**

- Throughput: 48-61 tokens/second
- Latency: 0.88-1.5s TTFT
- Context: 203K tokens

**Best For:** Budget coding tasks, agent workflows, front-end development, cost-sensitive deployments

**Avoid For:** Multimodal tasks, tasks requiring premium reasoning

---

## Comprehensive Benchmark Reference

| Model | SWE-bench | GPQA | LMArena | LiveCodeBench | Context | Throughput |
|-------|-----------|------|---------|---------------|---------|------------|
| Claude Opus 4.5 | Strong | Strong | Top tier | Strong | 200K | 24 tok/s |
| Claude Sonnet 4.5 | **SOTA** | Strong | Top tier | **Leader** | 1M | 48-68 tok/s |
| Claude Haiku 4.5 | 73%+ | Good | High | Good | 200K | **129 tok/s** |
| Gemini 3 Pro | **Leader** | **Diamond** | **#1** | Strong | 1.05M | 76-82 tok/s |
| Gemini 3 Flash | Strong | Strong | High | Strong | 1.05M | 75-123 tok/s |
| GPT-5.2 | Strong | Strong | High | Strong | 400K | Adaptive |
| Grok 4 | Good | Good | High | Good | 256K | 72-95 tok/s |
| Grok Code Fast 1 | Good | - | - | Good | 256K | 89 tok/s |
| Kimi K2 | High | High | High | **Leader** | 128K | Variable |
| Kimi K2 Thinking | High | High | High | High | 256K | Variable |
| GLM 4.7 | Good | Good | Solid | Good | 203K | 48-61 tok/s |

---

## Price Comparison (per 1M tokens)

| Tier | Model | Input | Output | Best Value For |
|------|-------|-------|--------|----------------|
| **Budget** | Grok Code Fast 1 | $0.20 | $1.50 | Agentic coding |
| | GLM 4.7 | $0.40 | $1.50 | General coding |
| | Kimi K2 Thinking | $0.40 | $1.75 | Extended reasoning |
| | Kimi K2 | $0.456 | $1.84 | Tool orchestration |
| **Value** | Gemini 3 Flash | $0.50 | $3.00 | Multimodal + speed |
| | Claude Haiku 4.5 | $1.00 | $5.00 | Fast Claude tasks |
| **Mid-tier** | GPT-5.2 | $1.75 | $14.00 | Balanced reasoning |
| | Gemini 3 Pro | $2.00 | $12.00 | Premium multimodal |
| **Premium** | Grok 4 | $3.00 | $15.00 | Complex reasoning |
| | Claude Sonnet 4.5 | $3.00 | $15.00 | Production coding |
| **Frontier** | Claude Opus 4.5 | $5.00 | $25.00 | Maximum capability |

---

## Quick Decision Matrix

| Need | Recommended Model | Why |
|------|-------------------|-----|
| Cheapest coding | Grok Code Fast 1 | $0.20 input, visible thinking |
| Best value coding | GLM 4.7 | $0.40 input, 203K context |
| Fastest responses | Claude Haiku 4.5 | 129 tok/s, 0.7s latency |
| Longest context | Gemini 3 Pro/Flash, Claude Sonnet 4.5 | 1M+ tokens |
| Best multimodal | Gemini 3 Pro | Text/image/audio/video, SOTA |
| Maximum reasoning | Claude Opus 4.5 | Frontier capability |
| Many tool calls | Kimi K2 Thinking | 200-300+ stable calls |
| Scientific research | Gemini 3 Pro | GPQA Diamond leader |
| Production SWE | Claude Sonnet 4.5 | SWE-bench SOTA |
