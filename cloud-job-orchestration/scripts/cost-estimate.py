#!/usr/bin/env python3
"""
Cost estimation calculator for cloud ML training jobs.

Supports: Vertex AI (GCP), SageMaker (AWS), RunPod

Usage:
    python cost-estimate.py --machine-type a2-highgpu-1g --hours 24
    python cost-estimate.py --platform sagemaker --instance-type ml.p4d.24xlarge --hours 48
    python cost-estimate.py --platform runpod --gpu-type "NVIDIA H100 80GB" --hours 12
"""

# /// script
# dependencies = [
#   "tabulate>=0.9.0",
# ]
# ///

import argparse
import sys
from dataclasses import dataclass
from typing import Optional

try:
    from tabulate import tabulate
except ImportError:
    def tabulate(data, headers, **kwargs):
        # Simple fallback
        print(" | ".join(headers))
        print("-" * 50)
        for row in data:
            print(" | ".join(str(x) for x in row))


# Pricing data (USD per hour) - Approximate, update as needed
VERTEX_AI_PRICING = {
    # A3 Series (H100)
    "a3-highgpu-1g": {"on_demand": 4.50, "spot": 1.35, "gpu": "H100 80GB", "gpus": 1},
    "a3-highgpu-2g": {"on_demand": 9.00, "spot": 2.70, "gpu": "H100 80GB", "gpus": 2},
    "a3-highgpu-4g": {"on_demand": 18.00, "spot": 5.40, "gpu": "H100 80GB", "gpus": 4},
    "a3-highgpu-8g": {"on_demand": 36.00, "spot": 10.80, "gpu": "H100 80GB", "gpus": 8},
    "a3-megagpu-8g": {"on_demand": 40.00, "spot": 12.00, "gpu": "H100 Mega", "gpus": 8},
    "a3-ultragpu-8g": {"on_demand": 48.00, "spot": 14.40, "gpu": "H200 141GB", "gpus": 8},
    
    # A2 Series (A100)
    "a2-highgpu-1g": {"on_demand": 3.67, "spot": 1.10, "gpu": "A100 40GB", "gpus": 1},
    "a2-highgpu-2g": {"on_demand": 7.34, "spot": 2.20, "gpu": "A100 40GB", "gpus": 2},
    "a2-highgpu-4g": {"on_demand": 14.68, "spot": 4.40, "gpu": "A100 40GB", "gpus": 4},
    "a2-highgpu-8g": {"on_demand": 29.36, "spot": 8.81, "gpu": "A100 40GB", "gpus": 8},
    "a2-ultragpu-1g": {"on_demand": 4.50, "spot": 1.35, "gpu": "A100 80GB", "gpus": 1},
    "a2-ultragpu-8g": {"on_demand": 36.00, "spot": 10.80, "gpu": "A100 80GB", "gpus": 8},
    "a2-megagpu-16g": {"on_demand": 58.72, "spot": 17.62, "gpu": "A100 40GB", "gpus": 16},
    
    # G2 Series (L4)
    "g2-standard-4": {"on_demand": 0.80, "spot": 0.24, "gpu": "L4", "gpus": 1},
    "g2-standard-8": {"on_demand": 1.00, "spot": 0.30, "gpu": "L4", "gpus": 1},
    "g2-standard-24": {"on_demand": 1.60, "spot": 0.48, "gpu": "L4", "gpus": 2},
    "g2-standard-48": {"on_demand": 3.20, "spot": 0.96, "gpu": "L4", "gpus": 4},
    
    # N1 with GPUs
    "n1-standard-4": {"on_demand": 0.19, "spot": 0.06, "gpu": "N/A", "gpus": 0},
    "n1-standard-8": {"on_demand": 0.38, "spot": 0.11, "gpu": "N/A", "gpus": 0},
    "n1-standard-16": {"on_demand": 0.76, "spot": 0.23, "gpu": "N/A", "gpus": 0},
    "n1-standard-32": {"on_demand": 1.52, "spot": 0.46, "gpu": "N/A", "gpus": 0},
}

# GPU-only pricing (add to machine type)
GPU_PRICING = {
    "NVIDIA_TESLA_T4": 0.35,
    "NVIDIA_TESLA_V100": 2.48,
    "NVIDIA_TESLA_P100": 1.46,
    "NVIDIA_TESLA_P4": 0.60,
    "NVIDIA_TESLA_A100": 2.48,
    "NVIDIA_A100_80GB": 3.67,
    "NVIDIA_H100_80GB": 4.50,
    "NVIDIA_L4": 0.80,
}

# SageMaker pricing
SAGEMAKER_PRICING = {
    "ml.p4d.24xlarge": {"on_demand": 32.77, "spot": 9.83, "gpu": "A100", "gpus": 8},
    "ml.p4de.24xlarge": {"on_demand": 40.96, "spot": 12.29, "gpu": "A100 80GB", "gpus": 8},
    "ml.p5.48xlarge": {"on_demand": 98.32, "spot": 29.50, "gpu": "H100", "gpus": 8},
    "ml.g5.xlarge": {"on_demand": 1.41, "spot": 0.42, "gpu": "A10G", "gpus": 1},
    "ml.g5.2xlarge": {"on_demand": 1.75, "spot": 0.53, "gpu": "A10G", "gpus": 1},
    "ml.g5.12xlarge": {"on_demand": 5.67, "spot": 1.70, "gpu": "A10G", "gpus": 4},
    "ml.g5.48xlarge": {"on_demand": 16.29, "spot": 4.89, "gpu": "A10G", "gpus": 8},
    "ml.g6.xlarge": {"on_demand": 1.32, "spot": 0.40, "gpu": "L4", "gpus": 1},
    "ml.g6e.xlarge": {"on_demand": 2.05, "spot": 0.62, "gpu": "L40S", "gpus": 1},
}

# RunPod pricing (Community cloud - approximate)
RUNPOD_PRICING = {
    "NVIDIA H100 80GB HBM3": 2.49,
    "NVIDIA H100 NVL": 2.29,
    "NVIDIA A100 80GB PCIe": 1.99,
    "NVIDIA A100-SXM4-80GB": 1.89,
    "NVIDIA A100 80GB SXM": 1.79,
    "NVIDIA RTX A6000": 0.79,
    "NVIDIA RTX 4090": 0.69,
    "NVIDIA RTX 3090": 0.49,
    "NVIDIA A40": 0.79,
    "NVIDIA A10": 0.65,
    "NVIDIA L40S": 1.19,
    "NVIDIA L4": 0.39,
}


@dataclass
class CostEstimate:
    platform: str
    instance_type: str
    hours: float
    on_demand_cost: float
    spot_cost: Optional[float]
    gpu_type: str
    gpu_count: int
    
    @property
    def savings_percent(self) -> Optional[float]:
        if self.spot_cost is None:
            return None
        return ((self.on_demand_cost - self.spot_cost) / self.on_demand_cost) * 100


def estimate_vertex_ai(machine_type: str, hours: float, accelerator_type: str = None, 
                       accelerator_count: int = 0, use_spot: bool = False) -> CostEstimate:
    """Estimate cost for Vertex AI."""
    
    if machine_type not in VERTEX_AI_PRICING:
        available = ", ".join(VERTEX_AI_PRICING.keys())
        raise ValueError(f"Unknown machine type: {machine_type}. Available: {available}")
    
    pricing = VERTEX_AI_PRICING[machine_type]
    
    # Base machine cost
    hourly = pricing["spot" if use_spot else "on_demand"]
    
    # Add GPU cost for N1 machines
    if accelerator_type and accelerator_count > 0:
        if machine_type.startswith("n1-"):
            gpu_hourly = GPU_PRICING.get(accelerator_type, 0)
            hourly += gpu_hourly * accelerator_count
    
    total = hourly * hours
    spot_hourly = pricing.get("spot")
    spot_total = spot_hourly * hours if spot_hourly else None
    
    return CostEstimate(
        platform="Vertex AI",
        instance_type=machine_type,
        hours=hours,
        on_demand_cost=total if not use_spot else spot_total,
        spot_cost=spot_total if not use_spot else None,
        gpu_type=pricing.get("gpu", accelerator_type or "N/A"),
        gpu_count=pricing.get("gpus", accelerator_count),
    )


def estimate_sagemaker(instance_type: str, hours: float, use_spot: bool = False) -> CostEstimate:
    """Estimate cost for SageMaker."""
    
    if instance_type not in SAGEMAKER_PRICING:
        available = ", ".join(SAGEMAKER_PRICING.keys())
        raise ValueError(f"Unknown instance type: {instance_type}. Available: {available}")
    
    pricing = SAGEMAKER_PRICING[instance_type]
    hourly = pricing["spot" if use_spot else "on_demand"]
    total = hourly * hours
    spot_hourly = pricing.get("spot")
    spot_total = spot_hourly * hours if spot_hourly else None
    
    return CostEstimate(
        platform="SageMaker",
        instance_type=instance_type,
        hours=hours,
        on_demand_cost=total if not use_spot else spot_total,
        spot_cost=spot_total if not use_spot else None,
        gpu_type=pricing["gpu"],
        gpu_count=pricing["gpus"],
    )


def estimate_runpod(gpu_type: str, hours: float, gpu_count: int = 1) -> CostEstimate:
    """Estimate cost for RunPod."""
    
    # Try exact match first
    hourly = RUNPOD_PRICING.get(gpu_type)
    
    # Try fuzzy match
    if hourly is None:
        for key, price in RUNPOD_PRICING.items():
            if gpu_type.lower() in key.lower():
                hourly = price
                gpu_type = key
                break
    
    if hourly is None:
        available = ", ".join(RUNPOD_PRICING.keys())
        raise ValueError(f"Unknown GPU type: {gpu_type}. Available: {available}")
    
    total = hourly * hours * gpu_count
    
    return CostEstimate(
        platform="RunPod",
        instance_type=gpu_type,
        hours=hours,
        on_demand_cost=total,
        spot_cost=None,  # RunPod community pricing is already low
        gpu_type=gpu_type,
        gpu_count=gpu_count,
    )


def format_currency(amount: float) -> str:
    return f"${amount:,.2f}"


def main():
    parser = argparse.ArgumentParser(description="Estimate cloud ML training costs")
    parser.add_argument("--platform", "-p", choices=["vertex", "sagemaker", "runpod"], 
                       default="vertex", help="Cloud platform")
    parser.add_argument("--machine-type", "-m", help="Machine type (Vertex)")
    parser.add_argument("--instance-type", help="Instance type (SageMaker)")
    parser.add_argument("--gpu-type", "-g", help="GPU type (RunPod or Vertex N1)")
    parser.add_argument("--accelerator-type", "-a", help="Accelerator type (Vertex N1)")
    parser.add_argument("--accelerator-count", type=int, default=0, help="Number of accelerators")
    parser.add_argument("--gpu-count", type=int, default=1, help="Number of GPUs (RunPod)")
    parser.add_argument("--hours", "-t", type=float, required=True, help="Training hours")
    parser.add_argument("--use-spot", "-s", action="store_true", help="Use spot/preemptible")
    parser.add_argument("--compare", "-c", action="store_true", help="Compare on-demand vs spot")
    parser.add_argument("--list-machines", action="store_true", help="List available machine types")
    
    args = parser.parse_args()
    
    if args.list_machines:
        print("\n=== Vertex AI Machine Types ===")
        data = [[mt, p["gpu"], p["gpus"], f"${p['on_demand']:.2f}", f"${p['spot']:.2f}"] 
                for mt, p in sorted(VERTEX_AI_PRICING.items())]
        print(tabulate(data, headers=["Machine Type", "GPU", "Count", "On-Demand/hr", "Spot/hr"]))
        
        print("\n=== SageMaker Instance Types ===")
        data = [[it, p["gpu"], p["gpus"], f"${p['on_demand']:.2f}", f"${p['spot']:.2f}"] 
                for it, p in sorted(SAGEMAKER_PRICING.items())]
        print(tabulate(data, headers=["Instance Type", "GPU", "Count", "On-Demand/hr", "Spot/hr"]))
        
        print("\n=== RunPod GPU Types (Community Cloud) ===")
        data = [[gpu, f"${price:.2f}"] for gpu, price in sorted(RUNPOD_PRICING.items())]
        print(tabulate(data, headers=["GPU Type", "/hr"]))
        return
    
    try:
        if args.platform == "vertex":
            machine = args.machine_type
            if not machine:
                print("Error: --machine-type required for Vertex AI")
                sys.exit(1)
            
            estimate = estimate_vertex_ai(
                machine, args.hours, 
                args.accelerator_type, args.accelerator_count,
                args.use_spot
            )
            
            if args.compare and not args.use_spot:
                spot_estimate = estimate_vertex_ai(
                    machine, args.hours,
                    args.accelerator_type, args.accelerator_count,
                    use_spot=True
                )
            else:
                spot_estimate = None
                
        elif args.platform == "sagemaker":
            instance = args.instance_type
            if not instance:
                print("Error: --instance-type required for SageMaker")
                sys.exit(1)
            
            estimate = estimate_sagemaker(instance, args.hours, args.use_spot)
            
            if args.compare and not args.use_spot:
                spot_estimate = estimate_sagemaker(instance, args.hours, use_spot=True)
            else:
                spot_estimate = None
                
        elif args.platform == "runpod":
            gpu = args.gpu_type
            if not gpu:
                print("Error: --gpu-type required for RunPod")
                sys.exit(1)
            
            estimate = estimate_runpod(gpu, args.hours, args.gpu_count)
            spot_estimate = None
        
        # Display results
        print(f"\n{'='*60}")
        print(f"💰 Cost Estimate: {estimate.platform}")
        print(f"{'='*60}")
        print(f"Instance/GPU: {estimate.instance_type}")
        print(f"GPU Type:     {estimate.gpu_type}")
        print(f"GPU Count:    {estimate.gpu_count}")
        print(f"Duration:     {estimate.hours} hours")
        print(f"{'-'*60}")
        
        if args.use_spot:
            print(f"Pricing:      Spot/Preemptible")
            print(f"Total Cost:   {format_currency(estimate.on_demand_cost)}")
        else:
            print(f"Pricing:      On-Demand")
            print(f"Total Cost:   {format_currency(estimate.on_demand_cost)}")
            
            if spot_estimate:
                savings = estimate.on_demand_cost - spot_estimate.on_demand_cost
                pct = (savings / estimate.on_demand_cost) * 100
                print(f"\n💡 With Spot VMs:")
                print(f"   Spot Cost:  {format_currency(spot_estimate.on_demand_cost)}")
                print(f"   Savings:    {format_currency(savings)} ({pct:.1f}%)")
        
        print(f"{'='*60}\n")
        
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
