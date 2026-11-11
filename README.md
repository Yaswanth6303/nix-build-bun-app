# Declarative Docker Images with Nix

This project demonstrates how to use **Nix** to declaratively build OCI-compliant (Docker) container images. 

## The Problem with Traditional Docker

Building container images with a standard `Dockerfile` has several hidden flaws:
1. **Unreliable Locks (Tags):** Docker tags like `node:latest` or `bun:1` are mutable. They can be overwritten, meaning two builds on different machines might pull different base images.
2. **Environment Drift:** Even with identical Dockerfiles, differences in build cache or the time of build can result in completely different environments and hard-to-reproduce bugs.
3. **Cross-Architecture Complexity:** Building an image for multiple platforms (e.g., x86 and ARM) usually requires complex CI/CD setups or QEMU emulation.

### The Mac vs. Linux Problem
If you are developing on a Mac (macOS / Darwin) but need to build a Docker image (which is strictly Linux), traditional tools rely on hidden Linux Virtual Machines. If you try to use Nix naively on a Mac to build a Linux container, Nix will error out because it expects a local Linux machine to execute the build script.

## The Nix Advantage & Solution

Nix solves these problems using **Declarative Configuration** and **Cross-Compilation**:
- **Reproducibility:** Nix uses a declarative language and a `flake.lock` file to cryptographically pin *every single dependency* down to the system level. The build environment is 100% identical across any machine.
- **Docker Integration:** Nix doesn't replace Docker; instead, we use `pkgs.dockerTools.buildLayeredImage` to natively generate OCI-compliant image tarballs that can be loaded into Docker or Kubernetes.
- **Cross-Architecture Builds (The Mac Fix):** We solved the macOS problem by instructing Nix to use your Mac's native build tools to package the files, but explicitly pulling pre-compiled **Linux binaries** (`bun`, `bash`, `coreutils`) for the container runtime. This allows you to build Linux containers instantly and natively on a Mac, without needing a Linux VM.

---

## Step-by-Step Guide

### 1. Develop Locally (Optional)
Using `nix develop` allows you to enter a shell that strictly mirrors the production environment exactly as defined in `flake.nix`.
```bash
nix develop
```

### 2. Build the Container Image
Run the Nix build command. Because of the cross-architecture mapping we set up, this will automatically build a Linux container regardless of whether you are on a Mac or a PC.
```bash
nix build
```
*(This creates a `result` file in your directory, which is a symlink to the image tarball in the Nix store).*

### 3. Load the Image into Docker
Load the newly built tarball directly into your local Docker daemon:
```bash
docker load < result
```

### 4. Run the Container
Your container is now in Docker! Start it and map the ports.

**If you are on an Apple Silicon (M1/M2/M3) Mac:**
```bash
docker run --rm -p 3000:3000 nix-bun-app-aarch64-linux:latest
```

**If you are on an Intel Mac or Linux PC:**
```bash
docker run --rm -p 3000:3000 nix-bun-app-x86_64-linux:latest
```

---

## Advanced: Cross-Compile for Another Architecture
Because Nix manages cross-compilation elegantly, you can build an image for a completely different architecture from your current machine.

For example, to build an **Intel (x86)** container from an **Apple Silicon (ARM)** Mac:
```bash
# 1. Build the explicit x86 target
nix build .#x86_64-linux

# 2. Load it
docker load < result

# 3. Run it
docker run --rm -p 3000:3000 nix-bun-app-x86_64-linux:latest
```

---

## 5. Push to Docker Hub
To share your built container on Docker Hub, you can use standard Docker commands after loading the image.

**1. Log in to Docker Hub:**
```bash
docker login
```

**2. Tag the image with your Docker Hub username:**
*(Replace `yourusername` with your actual Docker Hub username)*
```bash
# If you built the ARM/M-Series Mac version:
docker tag nix-bun-app-aarch64-linux:latest yourusername/nix-bun-app:latest

# If you built the Intel version:
docker tag nix-bun-app-x86_64-linux:latest yourusername/nix-bun-app:latest
```

**3. Push the image:**
```bash
docker push yourusername/nix-bun-app:latest
```

*(Alternatively, you can bypass the Docker Daemon completely and push the Nix tarball directly to Docker Hub using tools like [Skopeo](https://github.com/containers/skopeo): `skopeo copy docker-archive:result docker://yourusername/nix-bun-app:latest`)*

---

## 6. Create a True "Cross-Platform" Image (Docker Manifest)
If you push a single image tagged as `:latest`, it will only work natively for the architecture you built it for (e.g. ARM64 for M-series Macs). If someone pulls it on a different architecture, Docker will try to use a slow emulator.

To make a true multi-architecture image where `docker pull` automatically serves the correct CPU architecture for the user, you can use **Docker Manifests**. Since Nix allows cross-compilation, you can build both architectures on your Mac and link them together!

**1. Build, Tag, and Push BOTH architectures:**
```bash
# Build the ARM (Mac) version
nix build .#aarch64-linux
docker load < result
docker tag nix-bun-app-aarch64-linux:latest yourusername/nix-bun-app:arm64
docker push yourusername/nix-bun-app:arm64

# Build the Intel (PC/Server) version
nix build .#x86_64-linux
docker load < result
docker tag nix-bun-app-x86_64-linux:latest yourusername/nix-bun-app:amd64
docker push yourusername/nix-bun-app:amd64
```

**2. Create a Docker Manifest:**
Tell Docker Hub that `:latest` is a bundle containing both images:
```bash
docker manifest create yourusername/nix-bun-app:latest \
  yourusername/nix-bun-app:arm64 \
  yourusername/nix-bun-app:amd64
```

**3. Push the Manifest:**
```bash
docker manifest push yourusername/nix-bun-app:latest
```
Now, your image is completely cross-platform!
