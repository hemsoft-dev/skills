# AMD Ryzen AI Developer Platform software report

Research date: 2026-08-16

This report describes AMD's documented Linux image for the RAH-001 AMD Ryzen AI Halo Developer Platform. It does not claim that a particular machine still matches the factory image. The AMD Ryzen AI Developer Center is the source of truth for the packages and versions installed on a live unit.

## Bottom line

AMD designed the Linux image as an "AI first" system with curated software, models, and recovery controls already configured. The image centers on AMD ROCm, global Python and PyTorch, ComfyUI, Lemonade, developer tools, and a cache of models. AMD's Developer Center manages updates, exposes installed-package versions, changes shared GPU memory, and can roll the system back to an AMD snapshot or factory state. [AMD platform design blog](https://www.amd.com/en/blogs/2026/amd-ryzen-ai-developer-platform-open-ready-and-built.html) [AMD Ryzen AI Halo user guide](https://developer.amd.com/playbooks/user-guide/)

vLLM is the strongest documented serving path on the Linux image. AMD supplies it in a prebuilt container whose ROCm, PyTorch, and vLLM dependencies are matched. The `vllm-launch` wrapper starts that container on the integrated Radeon 8060S and publishes an OpenAI-compatible endpoint on port 8001. [AMD vLLM playbook](https://developer.amd.com/playbooks/vllm-inference/)

Ollama is supported on this hardware but is not part of AMD's explicit Linux pre-install inventory. AMD's Ollama playbook tells the user to install Ollama separately, then pull a model. Upstream Ollama now lists the Ryzen AI Max+ 395 and its `gfx1151` target as supported through ROCm on Linux. [AMD Ollama playbook](https://developer.amd.com/playbooks/ollama-getting-started/) [Ollama GPU support](https://github.com/ollama/ollama/blob/main/docs/gpu.mdx)

Neither vLLM nor Ollama uses the XDNA 2 NPU in AMD's documented playbooks. Both target the integrated Radeon 8060S GPU through ROCm. The NPU is a separate execution path for Ryzen AI and CVML workloads. [AMD vLLM playbook](https://developer.amd.com/playbooks/vllm-inference/) [AMD Ollama playbook](https://developer.amd.com/playbooks/ollama-getting-started/) [AMD product specifications](https://www.amd.com/en/products/processors/desktops/ryzen/ryzen-ai-halo/ryzen-ai-max-plus-395.html)

## Platform identity and hardware

AMD's legal guide identifies the physical product as model `RAH-001`. AMD markets it as the AMD Ryzen AI Halo Developer Platform. [AMD legal guide](https://www.amd.com/content/dam/amd/en/documents/products/processors/ryzen/ai/halo/amd-ryzen-ai-halo-legal-guide.pdf) [AMD product page](https://www.amd.com/en/products/processors/desktops/ryzen/ryzen-ai-halo/ryzen-ai-max-plus-395.html)

The documented configuration has:

| Component | AMD specification |
| --- | --- |
| CPU | Ryzen AI Max+ 395, 16 Zen 5 cores and 32 threads |
| GPU | Radeon 8060S integrated graphics, 40 RDNA 3.5 compute units |
| GPU architecture target | `gfx1151` |
| NPU | XDNA 2 |
| Memory | 128 GB LPDDR5x-8000 unified memory, 256 GB/s |
| Storage | 2 TB M.2 self-encrypting SSD |
| Network | 10 Gb Ethernet and Wi-Fi 7 |
| Power | 120 W TDP |
| Operating systems | AMD factory options for Linux or Windows 11 |

Sources: [AMD platform specifications](https://www.amd.com/en/products/processors/desktops/ryzen/ryzen-ai-halo/ryzen-ai-max-plus-395.html), [ROCm GPU architecture table](https://rocm.docs.amd.com/en/latest/reference/gpu-arch-specs.html), and [AMD user manual](https://www.amd.com/content/dam/amd/en/documents/products/processors/ryzen/ai/halo/amd-ryzen-ai-halo-user-manual.pdf).

The large-model capacity comes from unified memory. On Linux, AMD sets shared video memory to 75 percent by default, approximately 94 GB on a 128 GB unit. The Developer Center can adjust it from 10 to 90 percent in five-point steps. AMD's vLLM and Ollama playbooks call 96 GB the default shared pool and recommend the minimum 0.5 GB dedicated VRAM setting when maximizing the shared pool. A reboot applies memory changes. [AMD user guide](https://developer.amd.com/playbooks/user-guide/) [AMD vLLM playbook](https://developer.amd.com/playbooks/vllm-inference/) [AMD Ollama playbook](https://developer.amd.com/playbooks/ollama-getting-started/)

## What AMD intends the Linux image to provide

AMD says the platform is a Linux-based, curated environment. The operating system preloads inference software and selected models, while the Developer Center manages updates and recovery. AMD describes the system as having Debian heritage, but the public platform material reviewed for this report does not name a conventional Debian or Ubuntu release as the factory distribution. [AMD platform design blog](https://www.amd.com/en/blogs/2026/amd-ryzen-ai-developer-platform-open-ready-and-built.html)

First boot requires a mandatory online update before normal use. The Developer Center then opens automatically. Its Linux Manage page lists installed platform software, containers, models, available updates, and security-fix badges. Update All takes a system snapshot. Rollback restores that snapshot, while Factory Reset restores the out-of-box state and deletes user changes. [AMD user guide](https://developer.amd.com/playbooks/user-guide/)

### Explicit Linux pre-install inventory

AMD's May 2026 manual and current online user guide explicitly list the following Linux inventory after the Day-0 update. [AMD user manual](https://www.amd.com/content/dam/amd/en/documents/products/processors/ryzen/ai/halo/amd-ryzen-ai-halo-user-manual.pdf) [AMD online user guide](https://developer.amd.com/playbooks/user-guide/)

| Type | Documented items |
| --- | --- |
| AMD management | AMD Ryzen AI Developer Center |
| ROCm | ROCm Core SDK and ROCm profilers |
| Frameworks | Global Python and global PyTorch |
| Applications | ComfyUI, VS Code, Node.js, Git, Lemonade |
| Diffusion assets | Z Image Turbo, Qwen3 4B text encoder, AE VAE |
| LLM assets | GPT-OSS-120B, GPT-OSS-20B, Qwen3-Coder-30B-A3B-Instruct Q4_K_M |
| Model cache | `/var/cache/models` |

The image is meant to support AMD's main playbooks without rebuilding the base stack. Those main experiences cover PyTorch with ROCm, ComfyUI image generation, local coding with Qwen3-Coder, LM Studio serving, and n8n automation with GPT-OSS-120B. AMD also says the playbooks remain the installation and configuration source of truth even when the image has already supplied some pieces. [AMD user guide](https://developer.amd.com/playbooks/user-guide/)

### Platform-managed, optional, and user-installed software

| Software | Classification for the Linux image | Evidence |
| --- | --- | --- |
| ROCm, Python, PyTorch | Platform default | Listed in AMD's Linux pre-install inventory. [User guide](https://developer.amd.com/playbooks/user-guide/) |
| ComfyUI | Platform default, container-managed | Listed in the Linux inventory; the Developer Center manages its container. [User guide](https://developer.amd.com/playbooks/user-guide/) |
| Lemonade | Platform default | Listed in the Linux inventory. [User guide](https://developer.amd.com/playbooks/user-guide/) |
| vLLM | Platform-managed prebuilt container, with inventory ambiguity | AMD says no installation is required, `vllm-launch` starts the matched container, and the Developer Center manages the vLLM container. The compact Linux inventory table omits it. [vLLM playbook](https://developer.amd.com/playbooks/vllm-inference/) [User guide](https://developer.amd.com/playbooks/user-guide/) |
| Ollama | Optional, user-installed | AMD's playbook has an explicit installation step and the Linux inventory does not list Ollama. [Ollama playbook](https://developer.amd.com/playbooks/ollama-getting-started/) [User guide](https://developer.amd.com/playbooks/user-guide/) |
| llama.cpp | Optional, user-installed | AMD's clustering playbook installs and builds llama.cpp for ROCm and RPC. It is absent from the Linux inventory. [AMD llama.cpp RPC playbook](https://developer.amd.com/playbooks/clustering-rpc-server/) [User guide](https://developer.amd.com/playbooks/user-guide/) |
| LM Studio | Optional on Linux | AMD's playbooks tell Linux users to download an AppImage or Debian package. It is not in the Linux inventory. [AMD LM Studio playbook](https://developer.amd.com/playbooks/lmstudio-rocm-llms/) |
| Open WebUI, n8n, LLaMA Factory, Unsloth | Playbook additions, not base-image guarantees | AMD publishes playbooks for them, but the explicit Linux inventory does not list them. [AMD Playbooks repository](https://github.com/amd/playbooks) [User guide](https://developer.amd.com/playbooks/user-guide/) |

The classification above deliberately follows AMD's explicit inventory and install steps. AMD's product page shows logos for several compatible frameworks, but a logo is not evidence that the software ships in the factory image. [AMD Ryzen AI Halo overview](https://www.amd.com/en/products/processors/desktops/ryzen/ryzen-ai-halo.html)

## vLLM on the Ryzen AI Max+ 395

### AMD's platform path

AMD packages vLLM as a container with ROCm and its dependencies already matched. There is no host-side vLLM installation step. Running `vllm-launch` starts the container, targets the integrated GPU, and exposes the local OpenAI-compatible server. The Developer Center can start, stop, update, and reset the vLLM container. [AMD vLLM playbook](https://developer.amd.com/playbooks/vllm-inference/) [AMD user guide](https://developer.amd.com/playbooks/user-guide/)

The documented defaults are:

| Setting | AMD default |
| --- | --- |
| Command | `vllm-launch` |
| Model | `Qwen/Qwen3-1.7B` |
| Port | `8001` |
| API base | `http://localhost:8001/v1` |
| Health check | `http://localhost:8001/health` |
| AMD-validated models | `Qwen/Qwen3-1.7B` and `openai/gpt-oss-20b` |
| System model path | `/var/cache/models` |
| User model path | `~/.local/share/vLLM/models` |

Source: [AMD Getting Started with vLLM](https://developer.amd.com/playbooks/vllm-inference/).

The wrapper accepts a model ID or path, a different port, and extra vLLM arguments. AMD warns that arbitrary user-downloaded models in the two model directories are expected to work but have not all been validated. The platform guarantee is therefore narrower than upstream vLLM's full model catalog. [AMD vLLM playbook](https://developer.amd.com/playbooks/vllm-inference/) [upstream vLLM supported models](https://docs.vllm.ai/en/stable/models/supported_models/)

### Why this hardware is supported now

The current upstream vLLM hardware requirements explicitly include Ryzen AI MAX and AI 300 Series targets `gfx1151` and `gfx1150`. They require Linux and ROCm 7.0.2 or newer. Upstream also warns that its compiled ROCm kernels, PyTorch build, and ROCm build must stay compatible. AMD's pre-matched container addresses that exact dependency problem for the factory platform. [vLLM GPU requirements](https://docs.vllm.ai/en/stable/getting_started/installation/gpu/)

AMD's current ROCm Ryzen matrix lists the Ryzen AI Max+ 395 under `gfx1151`. The current matrix gives production support to PyTorch 2.9.1 with ROCm 7.2.1 and Python 3.12, with FP16 as the officially validated data type. These are the public ROCm compatibility values, not a claim about the exact versions in the current platform BKC. [ROCm Ryzen Linux compatibility matrix](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityryz/native_linux/native_linux_compatibility.html)

### Practical fit

vLLM is the best documented choice when a local application needs concurrent serving, continuous batching, or an OpenAI-compatible API. The curated container reduces the chance of mixing incompatible ROCm, PyTorch, Triton, and vLLM builds. This recommendation follows AMD's platform packaging and upstream vLLM's stated serving model. [AMD vLLM playbook](https://developer.amd.com/playbooks/vllm-inference/) [vLLM repository](https://github.com/vllm-project/vllm)

## Ollama on the Ryzen AI Max+ 395

AMD supports Ollama through a separate playbook. On Linux, the playbook tells the user to install the AMD GPU driver, run Ollama's official installation script, pull `gpt-oss:20b`, and use the CLI or REST API. The service listens on `http://localhost:11434`. [AMD Ollama playbook](https://developer.amd.com/playbooks/ollama-getting-started/)

Upstream Ollama explicitly lists Ryzen AI Max+ 395 under AMD ROCm support and maps it to `gfx1151`. Current Ollama Linux packages bundle ROCm 7 user-space libraries and require a compatible ROCm 7 kernel driver. Upstream also documents Vulkan as an additional backend, but ROCm is the direct, named support path for this APU. [Ollama GPU support](https://github.com/ollama/ollama/blob/main/docs/gpu.mdx) [Ollama troubleshooting guide](https://github.com/ollama/ollama/blob/main/docs/troubleshooting.mdx)

Ollama is the simpler choice for interactive local use, model pulls, a lightweight background service, and applications already written for Ollama's API. It does not inherit AMD's vLLM container pinning or vLLM's prevalidated model pair. AMD's playbook performs a separate `ollama pull`, so users should not assume Ollama automatically reuses the platform's `/var/cache/models` files. [AMD Ollama playbook](https://developer.amd.com/playbooks/ollama-getting-started/)

## Related supported paths

### PyTorch with ROCm

PyTorch and ROCm are base-image components, and AMD's playbooks create virtual environments with `--system-site-packages` so the environment can reuse the platform's global ROCm-enabled PyTorch. [AMD PyTorch LLM playbook](https://developer.amd.com/playbooks/pytorch-rocm-llms/) [AMD user guide](https://developer.amd.com/playbooks/user-guide/)

### ComfyUI

ComfyUI and its starting diffusion assets are preinstalled. AMD manages ComfyUI as a container on Linux. Upstream ComfyUI also publishes an RDNA 3.5 wheel path for `gfx1151`, which is the Radeon 8060S target. [AMD user guide](https://developer.amd.com/playbooks/user-guide/) [ComfyUI upstream README](https://github.com/Comfy-Org/ComfyUI/blob/master/README.md)

### Lemonade

Lemonade is preinstalled and provides another local-server layer. Its upstream documentation calls its vLLM ROCm backend experimental but says it has been validated on `gfx1151` Strix Halo and `gfx1150` Strix Point. Lemonade supplies its own self-contained vLLM bundle and exposes standard OpenAI-compatible endpoints through Lemonade Server. That is a separate packaging path from AMD's `vllm-launch` container. [Lemonade vLLM backend documentation](https://github.com/lemonade-sdk/lemonade/blob/main/docs/guide/configuration/vllm.md) [Lemonade repository](https://github.com/lemonade-sdk/lemonade)

### llama.cpp

llama.cpp is an optional path for GGUF models and distributed RPC inference. Upstream supports AMD through the HIP build option and also has a Vulkan backend. AMD's two-Halo clustering playbook uses llama.cpp with ROCm and RPC. Upstream labels the RPC backend a fragile and insecure proof of concept and says never to expose it to an open or sensitive network. [llama.cpp build guide](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md) [llama.cpp RPC warning](https://github.com/ggml-org/llama.cpp/blob/master/tools/rpc/README.md) [AMD RPC clustering playbook](https://developer.amd.com/playbooks/clustering-rpc-server/)

## Recommended operating model

1. Treat the Developer Center's Manage and System pages as the live inventory. Run AMD's updates before evaluating a failure because the factory snapshot can be older than the current BKC. [AMD user guide](https://developer.amd.com/playbooks/user-guide/)
2. Start with `vllm-launch` for a local OpenAI-compatible service. It is the platform's most tightly curated LLM server path. [AMD vLLM playbook](https://developer.amd.com/playbooks/vllm-inference/)
3. Install Ollama only when its CLI, registry, or API is the desired interface. Its `gfx1151` support is official upstream, but it remains outside the explicit AMD Linux pre-install inventory. [Ollama GPU support](https://github.com/ollama/ollama/blob/main/docs/gpu.mdx) [AMD Ollama playbook](https://developer.amd.com/playbooks/ollama-getting-started/)
4. Keep the AMD-curated and user-managed stacks separate. Do not replace the global ROCm or PyTorch packages merely to update one application. Use a container, a virtual environment, or the application's own bundle. This follows AMD's BKC recovery model and upstream vLLM's warning about binary compatibility. [AMD user guide](https://developer.amd.com/playbooks/user-guide/) [vLLM GPU installation guide](https://docs.vllm.ai/en/stable/getting_started/installation/gpu/)
5. Run one large GPU server at a time unless the workload has been measured. vLLM, Ollama, ComfyUI, and Lemonade compete for the same shared GPU memory. This is an inference from the platform's unified-memory design and the fact that these tools all target the Radeon GPU. [AMD memory configuration](https://developer.amd.com/playbooks/vllm-inference/) [AMD product specifications](https://www.amd.com/en/products/processors/desktops/ryzen/ryzen-ai-halo/ryzen-ai-max-plus-395.html)

## Uncertainties and documentation conflicts

- AMD does not publish a stable web manifest with every current BKC package name and version. The Developer Center displays those values on the device. The exact image version, ROCm version, PyTorch version, and container digest must be read from the live unit. [AMD user guide](https://developer.amd.com/playbooks/user-guide/)
- The compact Linux inventory in AMD's manual omits vLLM. Later in the same guide, AMD lists vLLM among installed developer-platform packages, describes it as a managed container, and the vLLM playbook says no installation is required. This report therefore classifies vLLM as platform-managed but flags the inventory inconsistency. [AMD user guide](https://developer.amd.com/playbooks/user-guide/) [AMD vLLM playbook](https://developer.amd.com/playbooks/vllm-inference/)
- AMD's Playbooks index currently labels the Ollama playbook "Pre-Installed," but the platform's explicit Linux inventory omits Ollama and the playbook tells the user to run Ollama's installer. The explicit inventory and install procedure are stronger evidence, so this report classifies Ollama as optional until the live Developer Center shows otherwise. [AMD Playbooks index](https://developer.amd.com/playbooks/) [AMD user guide](https://developer.amd.com/playbooks/user-guide/) [AMD Ollama playbook](https://developer.amd.com/playbooks/ollama-getting-started/)
- AMD's first-boot text calls LM Studio and VS Code optional installation examples, while the explicit Linux inventory lists VS Code as preinstalled. The live Developer Center resolves whether a particular image includes VS Code or offers it as an install. [AMD user manual](https://www.amd.com/content/dam/amd/en/documents/products/processors/ryzen/ai/halo/amd-ryzen-ai-halo-user-manual.pdf)
- AMD's public ROCm support matrix moves faster than the platform image. The matrix's current supported versions should not be substituted for the BKC versions without checking the Developer Center. [ROCm Ryzen Linux compatibility matrix](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityryz/native_linux/native_linux_compatibility.html) [AMD platform design blog](https://www.amd.com/en/blogs/2026/amd-ryzen-ai-developer-platform-open-ready-and-built.html)
- Upstream support does not mean every model and optimization is validated on the Radeon 8060S. AMD validates a narrow vLLM starting set, and Lemonade describes its own vLLM ROCm path as experimental. [AMD vLLM playbook](https://developer.amd.com/playbooks/vllm-inference/) [Lemonade vLLM backend documentation](https://github.com/lemonade-sdk/lemonade/blob/main/docs/guide/configuration/vllm.md)
