## Airfield: Design, Architecture, and Uses in the Wild for Reproducible Robotics 

1[st] Placeholder Author 

_Department of Computer Science The University of Texas at Austin_ Austin, TX, USA email@domain.edu 

2[nd] Placeholder Author _Department of Computer Science The University of Texas at Austin_ Austin, TX, USA email@domain.edu 

_**Abstract**_ **—Modern robotics software ecosystems, such as the Robot Operating System (ROS), rely on a complex web of dependencies that are challenging to install and deploy in a repeatable manner across diverse hardware platforms. The proliferation of edge accelerators, varying operating systems, and disparate host architectures, such as x86 64 processors for simulation and ARM64 devices used during deployment, exacerbates the friction of onboarding and integration. In this paper, we introduce Airfield, a package-centric robotics framework designed to orchestrate reproducible, hardware-accelerated, cross-platform containerized environments. By treating hardware dependencies, such as NVIDIA GPUs and CUDA toolkits, as first-class citizens mapped through declarative manifests, Airfield abstracts the complexity of environment management. We present the design and architecture of Airfield, detailing its command-line model, dependency resolution, and workspace orchestration. To evaluate its efficacy “in the wild,” we present a case study of migrating the Roboracer workspace—a 1/10th scale autonomous vehicle platform utilized for education and research—to Airfield. Finally, we conduct structured interviews with roboticists interacting with the platform, demonstrating a significant reduction in setup time, mitigation of hardware-specific friction, and an overall improvement in the developer experience.** 

_**Index Terms**_ **—Robotics Software, Reproducibility, Containers, ROS, Dependency Management** 

## I. INTRODUCTION 

The development of modern robotic systems requires integrating sophisticated algorithms spanning perception, planning, and control [1]. The Robot Operating System (ROS) and its successor, ROS 2, have provided the foundational middleware for these systems [2]. However, as robotics software matures, the sheer volume of system dependencies, thirdparty libraries, and hardware-specific drivers (e.g., NVIDIA Jetson packages, CUDA toolkits) introduces immense friction in configuring reproducible development and deployment environments. 

While containerization technologies like Docker have become ubiquitous in mitigating dependency conflicts [3], adapting them for hardware-accelerated robotics workloads remains non-trivial. Developers often resort to maintaining fragmented shell scripts, complex docker-compose files, or manually configuring X11 forwarding and device mounts for simulation and hardware interfaces. This fragmentation impedes crossplatform collaboration, particularly when the same software stack must target an x86 64 workstation for simulation (e.g., 

macOS or Linux) and an ARM64 embedded device for realworld execution. 

To address these challenges, we present **Airfield** , a packagecentric framework that standardizes environment creation, dependency management, and execution for complex robotics workspaces. Drawing inspiration from the widespread success of structured workflows in modern web and systems programming, Airfield bridges the gap between raw container engines and the specific demands of ROS 2 ecosystems. 

The primary contributions of this paper are: 

- 1) The design and architecture of the Airfield framework, which enables declarative, cross-platform dependency resolution for containerized hardware-accelerated robotics environments. 

- 2) A “uses in the wild” case study detailing the deployment of Airfield on the Roboracer 1/10th scale autonomous driving platform, demonstrating seamless transitions between macOS ARM64 simulation and NVIDIA Jetson Orin deployment. 

- 3) An empirical evaluation based on structured interviews with roboticists, assessing the qualitative impact of Airfield on onboarding, reproducibility, and development workflow. 

## II. RELATED WORK 

## _A. Standard ROS Workspaces and rosdep_ 

The conventional approach to managing ROS dependencies relies on rosdep, which resolves package dependencies against system package managers (e.g., apt on Ubuntu). While rosdep ensures that required libraries are installed on the host system, it does not provide environment isolation. Consequently, developers frequently encounter “it works on my machine” issues caused by conflicting global package versions or varying host operating systems [1]. 

## _B. Containerized Workflows_ 

To circumvent host contamination and allow multiple users running different software stacks while sharing the same physical hardware, roboticists increasingly utilize Docker [3]. However, running GUI tools (e.g., RViz, Gazebo) or accessing hardware accelerators (e.g., NVIDIA GPUs) within Docker requires intricate configuration. Tools such as Rocker [4] 

extend Docker to automatically inject the necessary arguments for X11, Wayland, and GPU access. Despite Rocker’s utility, it operates primarily at the image execution level rather than providing a holistic, project-wide dependency management system. 

Other solutions, such as ADE (Agile Development Environment) and Visual Studio Code Dev Containers, offer structured development environments. However, ADE has steep learning curves and rigid structures, while Dev Containers tie the workflow to a specific IDE and often require manual curation of Dockerfiles for multi-architecture targets. Airfield distinguishes itself by offering an IDE-agnostic, declarative approach tailored explicitly for the cross-platform constraints of modern robotics. 

## III. DESIGN AND ARCHITECTURE 

Airfield is architected as a lightweight, CLI-driven framework that orchestrates Docker (or compatible container engines like Podman or Apptainer) using a declarative configuration model. Its core philosophy is to decouple the _source code_ from the _environment_ , avoiding the anti-pattern of copying actively developed code into static container layers. 

## _C. Host and Hardware Diagnostics_ 

Robotics workloads often depend on host-level drivers, such as the NVIDIA display driver, which must match the CUDA runtime injected into the container. Airfield includes a doctor command that performs proactive system checks. It detects GPU hardware, validates CUDA toolkit installations, and verifies container engine availability. If mismatches are detected, Airfield provides actionable remediation steps, downgrading errors to warnings gracefully when running nested within existing containers. 

## _D. Project Orchestration and Plans_ 

For complex robots comprising multiple packages (e.g., navigation, perception, control), Airfield introduces _Plans_ . Defined in plans/<name>.yaml, a plan aggregates multiple packages into a cohesive system. Users can execute airfield project liftoff to sequentially or parallelly bring up the required containers. Under the hood, Airfield integrates with tools like tmuxinator (airfield package up) to automatically generate and launch multipane terminal sessions bound to the respective package containers. 

## _A. Package-Centric Model_ 

At the heart of Airfield is the airfield.yaml configuration file, which defines a package’s identity, base image, and dependencies. Unlike monolithic project setups, Airfield treats individual components as discrete packages that declare their own requirements: 

name: perception_stack ros_distro: jazzy dependencies: 

- ros_base>=1.3,<2.0 

- cv_bridge==3.2.1 

source_path: src 

By specifying ros_distro, Airfield automatically resolves the correct underlying ROS base image (e.g., Humble, Jazzy) and injects the appropriate workspace overlays. The source_path directive ensures that the local code is mounted directly into the container at runtime, enabling instant feedback during development without rebuilding images. 

## _B. Cross-Platform Dependency Resolution_ 

A critical innovation of Airfield is its hierarchical, target-aware dependency resolution engine. Dependency manifests are organized by target architecture (e.g., dependencies/x86_64/ and dependencies/arm64/). When a user executes airfield package build, the framework aggregates the manifests corresponding to the detected host or specified target device. 

This enables a single source repository to transparently build distinct container images based on the platform. Furthermore, Airfield enforces semantic versioning policies, treating exact pins as lock values, ensuring that an environment built on one machine is exactly reproducible on another. 

## IV. USES IN THE WILD: THE ROBORACER PLATFORM 

To validate Airfield’s design, we deployed it within the **Roboracer** workspace, a 1/10th scale autonomous vehicle platform utilized by the Freshman Research Initiative (FRI) for Autonomous Driving at UT Austin. 

## _A. Platform Challenges_ 

The Roboracer platform relies on a sophisticated software stack encompassing ROS 2, Foxglove Studio for visualization, and various deep learning models. Prior to Airfield, onboarding students required executing a litany of manual configuration scripts. The deployment targets were split into two distinct modes: 

- **Simulation Mode:** Executed on students’ personal laptops (predominantly macOS ARM64 and Linux/Windows x86 64). 

- **Hardware Mode:** Executed directly on the vehicle’s onboard NVIDIA Jetson Orin (ARM64 with discrete GPU drivers). 

This bifurcation led to fragile docker-compose files and frequent “environment rot,” where updates to the simulator broke the hardware deployment, and vice versa. 

## _B. Migration to Airfield_ 

We migrated the roboracer_ws to the Airfield framework. The migration process involved initializing the project root and defining discrete packages for simulation and hardware interfaces. 

With Airfield, the workflow was condensed to a universal interface. A student clones the repository and executes: 

## airfield project run 

**==> picture [521 x 226] intentionally omitted <==**

**----- Start of picture text -----**<br>
A. Developer Workspace B. Airfield Framework Core C. Target Execution<br>v<br>Parse Build<br>Project Repository Airfield CLI & API Container Runner<br>_ [ r<br>airfield.yaml (Project) Live Source Code Mount<br>Dependency Resolution Engine<br>plans/*.yaml (Orchestration) ROS 2 Base Image<br>v A1<br>1 (Humble / Jazzy)<br>x86_64 Target arm64 Target 11<br>Manifests Manifests 1<br>vI<br>1<br>Packages (e.g., nav_stack) —> Parse Host & GPU Diagnostics (Doctor) —> Deploy H Hardware Layer 11<br>1<br>airfield.yaml (Package) NVIDIA Jetson / Edge O<br>Container Orchestration 110 (ARM64 + CUDA Mounts)<br>dependencies/ (Manifests) ,,<br>,<br>Image Layer Builder (Dockerfile Gen) ’ Simulation Host<br>,<br>source_path (Source Code) 1,’ (x86_64 Linux / macOS ARM64)<br>1 Tmuxinator Session / Runtime Hooks ¢<br>\‘ MS<br>noo<br>SSS Le<br>Se o-<br>se uec<br>Teel Zero-Copy Live Source Mount ueor”<br>**----- End of picture text -----**<br>


Fig. 1. Caption 

Airfield detects the underlying hardware (e.g., macOS ARM64 vs. Jetson Orin) and automatically resolves the correct dependencies. On a Jetson Orin, it dynamically maps the /dev/nvhost-* devices and mounts the local code. On a macOS laptop, it provisions the simulation environment without attempting to inject incompatible NVIDIA drivers. 

## V. USER FEEDBACK AND EVALUATION 

To assess the qualitative impact of Airfield, we conducted structured interviews with a cohort of roboticists (comprising undergraduate researchers, graduate students, and faculty) utilizing the Roboracer platform. 

## _A. Methodology_ 

Participants were asked to rate their experience with the legacy Docker-based setup versus the new Airfield framework. The interview focused on three vectors: (1) Onboarding time and friction, (2) Workflow efficiency during cross-platform development, and (3) Debugging environment-related errors. 

## _B. Results_ 

The feedback highlighted several key themes: 

- **Reduced Onboarding Friction:** Participants noted that the time required to achieve a “first successful compile” 

   - dropped from several hours (often spanning multiple days due to missing dependencies) to under ten minutes. 

- **Abstraction of Docker Complexity:** Users appreciated that they did not need to write or debug Dockerfiles. The abstraction provided by airfield package cmd and airfield package shell allowed them to interact with the container as if it were a native environment. 

- **Confidence in Reproducibility:** Advanced users reported higher confidence when deploying code to the physical car, noting that the tight coupling of architecturespecific dependency manifests prevented silent runtime failures on the Jetson Orin. 

One researcher stated: _“Before Airfield, moving an algorithm from my Mac to the Jetson felt like a coin toss. Now, the framework catches dependency mismatches before the container even builds.”_ 

## VI. CONCLUSION AND FUTURE WORK 

We presented Airfield, a novel, package-centric framework designed to resolve the pervasive issues of reproducibility and cross-platform dependency management in modern robotics. By mapping hardware requirements declaratively and standardizing the orchestration of containerized ROS environ- 

ments, Airfield significantly reduces development friction. Our case study on the Roboracer platform, corroborated by positive structured feedback from active roboticists, underscores the framework’s practical utility “in the wild.” 

Future work will focus on expanding Airfield’s integration with Continuous Integration/Continuous Deployment (CI/CD) pipelines and broadening the registry of standard dependency manifests to encompass ecosystems beyond ROS 2. 

## ACKNOWLEDGMENT 

We would like to thank the members of the Freshman Research Initiative for Autonomous Driving at The University of Texas at Austin for their feedback and participation in the case study. 

## REFERENCES 

- [1] S. Macenski, T. Foote, B. Gerkey, C. Lalancette, and W. Woodall, “Robot operating system 2: Design, architecture, and uses in the wild,” _Science Robotics_ , vol. 7, no. 66, p. eabm6074, 2022. 

- [2] M. Quigley, K. Conley, B. Gerkey, J. Faust, T. Foote, J. Leibs, R. Wheeler, and A. Y. Ng, “Ros: an open-source robot operating system,” _ICRA workshop on open source software_ , vol. 3, no. 3.2, p. 5, 2009. 

- [3] D. Merkel, “Docker: lightweight linux containers for consistent development and deployment,” _Linux journal_ , vol. 2014, no. 239, p. 2, 2014. 

- [4] T. Foote _et al._ , “Rocker: A tool to run docker images with customized local support,” https://github.com/osrf/rocker, 2019. 

