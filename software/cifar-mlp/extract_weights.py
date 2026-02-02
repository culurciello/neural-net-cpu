import torch
import sys
import os
import numpy as np
import torchvision
import torchvision.transforms as transforms

# Add the software directory to the python path
new_path = os.path.abspath(os.path.dirname(__file__))
sys.path.insert(0, new_path)

from model import MLP

VEC = 16

def float_to_fixed_point(value, bits=16, frac_bits=8):
    """Converts a float to a fixed-point integer."""
    scale = 2**frac_bits
    return int(round(value * scale))

def save_tensor_to_hex(tensor, filename, bits=16, frac_bits=8):
    """Saves a tensor to a hex file (scalar, one value per line)."""
    with open(filename, 'w') as f:
        tensor_flat = tensor.detach().numpy().flatten()
        for val in tensor_flat:
            fixed_point_val = float_to_fixed_point(val, bits, frac_bits)
            # Format as hex with the correct number of digits (e.g., 4 for 16-bit)
            hex_val = format(fixed_point_val & ((1 << bits) - 1), f'0{bits//4}x')
            f.write(hex_val + '\n')

def pack_values_to_hex(values, filename, bits=16):
    """Packs values into VEC-wide words, lane 0 in LSBs."""
    word_bits = bits * VEC
    word_mask = (1 << bits) - 1
    with open(filename, 'w') as f:
        for base in range(0, len(values), VEC):
            word = 0
            for lane in range(VEC):
                idx = base + lane
                if idx >= len(values):
                    val = 0
                else:
                    val = values[idx]
                word |= (val & word_mask) << (lane * bits)
            hex_val = format(word, f'0{word_bits//4}x')
            f.write(hex_val + '\n')

def save_input_vector_hex(image, filename, bits=16, frac_bits=8):
    """Saves a single CIFAR image tensor as packed vectors."""
    image_flat = image.detach().numpy().flatten()
    fixed_vals = [float_to_fixed_point(v, bits, frac_bits) for v in image_flat]
    pack_values_to_hex(fixed_vals, filename, bits)

def save_weights_vector_hex(weight_tensor, filename, bits=16, frac_bits=8):
    """Saves weights as packed vectors (per output neuron)."""
    weights = weight_tensor.detach().numpy()
    out_dim, in_dim = weights.shape
    fixed_vals = []
    for out_idx in range(out_dim):
        row = weights[out_idx]
        for in_idx in range(in_dim):
            fixed_vals.append(float_to_fixed_point(row[in_idx], bits, frac_bits))
    pack_values_to_hex(fixed_vals, filename, bits)

def main():
    # Load the trained model
    model_path = os.path.join(os.path.dirname(__file__), 'cifar_mlp.pth')
    model = MLP()
    model.load_state_dict(torch.load(model_path))
    model.eval()

    output_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'hardware', 'cifar-mlp'))
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Define fixed-point format
    BITS = 16
    FRAC_BITS = 8

    # Extract and save weights and biases
    params = {
        'fc1_weights': model.fc1.weight,
        'fc1_biases': model.fc1.bias,
        'fc2_weights': model.fc2.weight,
        'fc2_biases': model.fc2.bias,
        'fc3_weights': model.fc3.weight,
        'fc3_biases': model.fc3.bias,
    }

    for name, tensor in params.items():
        filename = os.path.join(output_dir, f'{name}.hex')
        if "weights" in name:
            save_weights_vector_hex(tensor, filename, BITS, FRAC_BITS)
        else:
            save_tensor_to_hex(tensor, filename, BITS, FRAC_BITS)
        print(f'Saved {name} to {filename}')

    # Load a random real CIFAR-10 input and save it for simulation
    data_root = os.path.join(os.path.dirname(__file__), 'data')
    transform = transforms.Compose(
        [transforms.ToTensor(),
         transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))])
    testset = torchvision.datasets.CIFAR10(root=data_root, train=False,
                                           download=False, transform=transform)
    idx = torch.randint(0, len(testset), (1,)).item()
    image, label = testset[idx]
    input_filename = os.path.join(output_dir, 'input.hex')
    save_input_vector_hex(image, input_filename, BITS, FRAC_BITS)
    print(f'Saved input to {input_filename} (test idx={idx}, label={label})')

if __name__ == '__main__':
    main()
