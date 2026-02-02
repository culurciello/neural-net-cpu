
import torch
from torchvision import transforms
from PIL import Image
from model import MLP
import replicate

class Predictor(replicate.predictor.Predictor):
    def setup(self):
        """Load the model into memory to make running multiple predictions efficient"""
        self.net = MLP()
        self.net.load_state_dict(torch.load('cifar_mlp.pth'))
        self.net.eval()
        self.transform = transforms.Compose([
            transforms.Resize((32, 32)),
            transforms.ToTensor(),
            transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
        ])
        self.classes = ('plane', 'car', 'bird', 'cat', 'deer', 'dog', 'frog', 'horse', 'ship', 'truck')

    def predict(self, image: replicate.File) -> str:
        """Run a single prediction on the model"""
        img = Image.open(image).convert('RGB')
        img = self.transform(img)
        img = img.unsqueeze(0)  # Add batch dimension

        with torch.no_grad():
            output = self.net(img)
            _, predicted = torch.max(output, 1)
            prediction = self.classes[predicted[0]]

        return prediction
