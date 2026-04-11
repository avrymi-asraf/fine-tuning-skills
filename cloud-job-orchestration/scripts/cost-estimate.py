#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "tabulate>=0.9.0",
# ]
# ///
"""
Estimate Vertex AI custom training job costs.

Usage:
    uv run scripts/cost-estimate.py --machine-type a2-highgpu-1g --hours 24
    uv run scripts/cost-estimate.py --machine-type a2-highgpu-1g --hours 24 --use-spot
    uv run scripts/cost-estimate.py --machine-type a2-highgpu-1g --hours 24 --compare
    uv run scripts/cost-estimate.py --list-machines
"""

import argparse
import sys

try:
    from tabulate import tabulate
except ImportError:
    def tabulate(data, headers, **kwargs):
        print(" | ".join(headers))
        print("-" * 60)
        for row in data:
            print(" | ".join(str(x) for x in row))


# Vertex AI pricing (USD per hour, approximate — verify at cloud.google.com/compute/gpus-pricing)
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
    # N1 with attachable GPUs (machine cost only — add GPU cost separately)
    "n1-standard-4": {"on_demand": 0.19, "spot": 0.06, "gpu": "N/A", "gpus": 0},
    "n1-standard-8": {"on_demand": 0.38, "spot": 0.11, "gpu": "N/A", "gpus": 0},
    "n1-standard-16": {"on_demand": 0.76, "spot": 0.23, "gpu": "N/A", "gpus": 0},
    "n1-standard-32": {"on_demand": 1.52, "spot": 0.46, "gpu": "N/A", "gpus": 0},
}

# GPU-only pricing (add to N1 machine cost)
GPU_PRICING = {
    "NVIDIA_TESLA_T4": 0.35,
    "NVIDIA_TESLA_V100": 2.48,
    "NVIDIA_TESLA_P100": 1.46,
    "NVIDIA_TESLA_A100": 2.48,
    "NVIDIA_A100_80GB": 3.67,
    "NVIDIA_H100_80GB": 4.50,
    "NVIDIA_L4": 0.80,
}


def estimate_cost(machine_type, hours, accelerator_type=None, accelerator_count=0, use_spot=False):
    """Calculate estimated cost for a Vertex AI job."""
    if machine_type not in VERTEX_AI_PRICING:
        available = ", ".join(sorted(VERTEX_AI_PRICING.keys()))
        print(f"Error: unknown machine type '{machine_type}'", file=sys.stderr)
        print(f"Available: {available}", file=sys.stderr)
        sys.exit(1)

    pricing = VERTEX_AI_PRICING[machine_type]
    pricing_tier = "spot" if use_spot else "on_demand"
    hourly = pricing[pricing_tier]

    # Add GPU cost for N1 machines with attached GPUs
    if accelerator_type and accelerator_count > 0 and machine_type.startswith("n1-"):
        gpu_hourly = GPU_PRICING.get(accelerator_type, 0)
        hourly += gpu_hourly * accelerator_count

    return hourly * hours, hourly


def main():
    parser = argparse.ArgumentParser(description="Estimate Vertex AI training job cost")
    parser.add_argument("--machine-type", "-m", help="Vertex AI machine type")
    parser.add_argument("--accelerator-type", "-a", help="Accelerator type (for N1 machines)")
    parser.add_argument("--accelerator-count", type=int, default=0, help="Number of accelerators")
    parser.add_argument("--hours", "-t", type=float, help="Training duration in hours")
    parser.add_argument("--use-spot", "-s", action="store_true", help="Use Spot VM pricing")
    parser.add_argument("--compare", "-c", action="store_true", help="Compare on-demand vs Spot")
    parser.add_argument("--list-machines", action="store_true", help="List all machine types with pricing")
    args = parser.parse_args()

    if args.list_machines:
        data = [
            [mt, p["gpu"], p["gpus"], f"${p['on_demand']:.2f}", f"${p['spot']:.2f}"]
            for mt, p in sorted(VERTEX_AI_PRICING.items())
        ]
        print(tabulate(data, headers=["Machine Type", "GPU", "Count", "On-Demand/hr", "Spot/hr"]))
        sys.exit(0)

    if not args.machine_type or not args.hours:
        parser.error("--machine-type and --hours are required")

    pricing = VERTEX_AI_PRICING[args.machine_type]

    total, hourly = estimate_cost(
        args.machine_type, args.hours,
        args.accelerator_type, args.accelerator_count,
        args.use_spot,
    )

    print(f"\n{'=' * 50}", file=sys.stderr)
    print(f"Cost Estimate: Vertex AI", file=sys.stderr)
    print(f"{'=' * 50}", file=sys.stderr)
    print(f"Machine:    {args.machine_type}", file=sys.stderr)
    print(f"GPU:        {pricing.get('gpu', 'N/A')} x{pricing.get('gpus', 0)}", file=sys.stderr)
    print(f"Duration:   {args.hours} hours", file=sys.stderr)
    print(f"Pricing:    {'Spot' if args.use_spot else 'On-Demand'}", file=sys.stderr)
    print(f"Rate:       ${hourly:.2f}/hr", file=sys.stderr)
    print(f"{'=' * 50}", file=sys.stderr)
    print(f"Total Cost: ${total:,.2f}", file=sys.stderr)

    if args.compare and not args.use_spot:
        spot_total, spot_hourly = estimate_cost(
            args.machine_type, args.hours,
            args.accelerator_type, args.accelerator_count,
            use_spot=True,
        )
        savings = total - spot_total
        pct = (savings / total) * 100
        print(f"\nWith Spot VMs:", file=sys.stderr)
        print(f"  Rate:     ${spot_hourly:.2f}/hr", file=sys.stderr)
        print(f"  Total:    ${spot_total:,.2f}", file=sys.stderr)
        print(f"  Savings:  ${savings:,.2f} ({pct:.0f}%)", file=sys.stderr)

    print(f"{'=' * 50}\n", file=sys.stderr)
    sys.exit(0)


if __name__ == "__main__":
    main()
