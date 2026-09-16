# MVM Engine

A parameterizable, pipelined matrix-vector multiplication (MVM) engine written in SystemVerilog, inspired by the compute tile architecture used in Microsoft's [BrainWave](https://www.microsoft.com/en-us/research/blog/microsoft-unveils-project-brainwave/) deep learning accelerator (Fowers et al., ISCA 2018).

The engine computes **result = Matrix × Vector** using a configurable number of parallel compute lanes, each with its own local matrix memory, a fully pipelined 8-wide dot product unit, and an accumulator. Meets timing at ~380 MHz on FPGA.

## Overview

Matrix-vector multiplication is the core operation in neural network inference — each fully connected or convolutional layer reduces, at some level, to repeated MVMs. This project implements a small, hardware-efficient MVM engine that streams arbitrarily large vectors and matrices through fixed-width 8-element dot product units, similar to how BrainWave's Matrix Vector Multiplication Unit (MVU) tiles work in Microsoft's datacenter FPGAs.

## Architecture

```
                     ┌─────────────┐
   i_vec_wdata ─────▶│ Vector Mem  │───┐
                     └─────────────┘    │ (broadcast to all lanes)
                                        │
        ┌───────────────────────────────┼───────────────────────────────┐
        │                               ▼                               │
        │   ┌─────────────┐      ┌───────────┐      ┌──────────┐        │
        │   │ Matrix Mem 0│────▶│  Dot8 #0  │─────▶│ Accum #0 │──▶ o_result[0]
        │   └─────────────┘      └───────────┘      └──────────┘        │
        │          ...                 ...                ...           │
        │   ┌──────────────┐      ┌───────────┐      ┌──────────┐       │
        │   │Matrix Mem N-1│────▶│ Dot8 #N-1 │─────▶│Accum #N-1│──▶ o_result[N-1]
        │   └──────────────┘      └───────────┘      └──────────┘       │
        └───────────────────────────────┬───────────────────────────────┘
                                        │
                                  Control FSM (ctrl.sv)
                            generates read addresses + timing
```

Each compute lane produces one element of the output vector per pass, so `NUM_OLANES` lanes running in parallel produce `NUM_OLANES` output elements simultaneously.

### Memory layout

Vectors and matrix rows are both split into 8-element words to match the dot product unit's width. The matrix is distributed round-robin across the `NUM_OLANES` matrix memories: lane `i` stores rows `i, i+NUM_OLANES, i+2×NUM_OLANES, ...`, each stored as `N/8` contiguous words. The vector memory holds the vector in the same word layout and is broadcast to every lane.

## Modules

| File | Description |
|---|---|
| `dot8.sv` | Fully pipelined 8-lane dot product unit (multiply + adder-tree reduction) |
| `accum.sv` | Accumulator — sums a stream of partial dot products into a running total, enabling arbitrary-length vector/row support |
| `ctrl.sv` | Control FSM — generates the vector/matrix memory read address sequence and accumulator control signals (`first`/`last`) that drive the datapath |
| `mvm.sv` | Top-level module — instantiates and connects the vector memory, per-lane matrix memories, dot product units, accumulators, and control FSM |
| `mem.sv` | Provided simple dual-port SRAM memory block (not authored by me — see Acknowledgments) |
| `mvm_tb.sv` | Provided testbench — writes randomized vector/matrix data, asserts `i_start`, and checks `o_result` against golden values |
| `*_tb.sv` | Created testbenches — module-specific testbenches created during development for verification of correctness and functionality |

## Parameters

| Parameter | Description | Default |
|---|---|---|
| `IWIDTH` | Bitwidth of vector/matrix input elements | 8 |
| `OWIDTH` | Bitwidth of output vector elements | 32 |
| `VEC_MEM_DEPTH` | Depth of the vector memory | 256 |
| `MAT_MEM_DEPTH` | Depth of each matrix memory | 512 |
| `NUM_OLANES` | Number of parallel output compute lanes | 8 |

## Results

- Fully functional MVM engine verified against the provided testbench for randomized matrix/vector sizes
- Meets timing at ~380 MHz post-implementation (target was 350 MHz)
- Resource utilization (DSP/BRAM) verified to scale as expected with `NUM_OLANES`

## Simulation

1. Add `dot8.sv`, `accum.sv`, `mem.sv`, `ctrl.sv`, and `mvm.sv` to a Vivado project
2. Add `mvm_tb.sv` as the simulation testbench
3. Run behavioral simulation — the testbench will report pass/fail against golden results
4. For implementation, synthesize out-of-context (`-mode out_of_context`) to avoid IO pin limits, then run post-implementation functional simulation to verify the netlist

## Acknowledgments

This project was originally developed as Lab 4 for [ECE 327: Digital Hardware Systems](https://uwaterloo.ca) at the University of Waterloo, taught by Andrew Boutros. The lab specification, module interfaces, `mem.sv` implementation, and testbench (`mvm_tb.sv`) were provided as course material. The datapath (`dot8.sv`, `accum.sv`), control FSM (`ctrl.sv`), and top-level integration (`mvm.sv`) are my own implementation.

The overall architecture is modeled after the Matrix Vector Multiplication Unit (MVU) tile described in:

> J. Fowers et al., "A Configurable Cloud-Scale DNN Processor for Real-Time AI," *International Symposium on Computer Architecture (ISCA)*, 2018.
