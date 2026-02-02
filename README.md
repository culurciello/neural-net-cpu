# Neural Net CPU

A tiny company building the ultimate neural network AI processor

![](images/nncpu.jpg)




## Example 1: CIFAR 


### Software

- `model.py`: Defines the 3-layer MLP architecture using PyTorch.
- `train.py`: Trains the MLP model on the CIFAR-10 dataset and saves the trained model to `cifar_mlp.pth`.
- `demo.py`: A simple command-line demo that loads the trained model, shows a few test images, and prints the model's predictions.
- `predict.py`: A Replicate-compatible predictor that takes an image and returns a prediction.
- `replicate.yaml`: Configuration file for running this model on Replicate.

To train the model, run:

```bash
python train.py
```

This will download the CIFAR-10 dataset, train the model for 5 epochs, and save the model to `cifar_mlp.pth`.

To run the command-line demo, run:

```bash
python demo.py
```

This will load the trained model, show 4 random images from the test set, and print the ground truth and predicted labels.


### Hardware 


#### File Structure

- `mlp.sv`: Top-level MLP module.
- `layer.sv`: A generic fully connected layer.
- `mac_unit.sv`: Multiply-Accumulate unit.
- `relu.sv`: ReLU activation function.
- `bram.sv`: A generic BRAM module.
- `timescale.vh`: Timescale definition for simulation.
- `mlp_tb.sv`: A testbench for the MLP.
- `extract_weights.py`: A Python script to extract weights and biases from the trained PyTorch model.
- `*.hex`: Hex files containing the weights, biases, and a dummy input for simulation.

#### Prerequisites

- Python 3.x
- PyTorch
- NumPy
- A SystemVerilog simulator (e.g., Icarus Verilog, ModelSim, QuestaSim, Vivado Simulator).
- Verilator (optional, for fast C++-based simulation).

#### How to Run

1. Weight Extraction

The hardware model needs the weights and biases from the trained software model. These are extracted and converted to a fixed-point hexadecimal format.

First, make sure you have the trained model file `software/cifar-mlp/cifar_mlp.pth`. If not, you need to run the training script in the `software/cifar-mlp` directory.

To extract the weights, run the following command from the root of the project:

```bash
python software/cifar-mlp/extract_weights.py
```

This will generate the `.hex` files for weights and biases in the `hardware/cifar-mlp` directory.


2. Verilator simulation

A simple Makefile is provided for Verilator builds that keeps generated files under `hardware/cifar-mlp/obj_dir`.

From the project root:

```bash
make -C hardware/cifar-mlp
```

To run the simulation:

```bash
make -C hardware/cifar-mlp run
```

To clean:

```bash
make -C hardware/cifar-mlp clean
```
