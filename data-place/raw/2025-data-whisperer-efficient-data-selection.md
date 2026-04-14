# Data Whisperer: Efficient Data Selection for Task-Specific LLM Fine-Tuning via Few-Shot In-Context Learning

**Authors:** Shaobo Wang, Xiangqi Jin, Ziming Wang, Jize Wang, Jiajun Zhang, Kaixin Li, Zichen Wen, Zhong Li, Conghui He, Xuming Hu, Linfeng Zhang  
**Published:** ACL 2025 (63rd Annual Meeting, Vienna)  
**URL:** https://aclanthology.org/2025.acl-long.1135/  
**arXiv:** 2505.12212

## Abstract

Fine-tuning large language models (LLMs) on task-specific data is essential for effective deployment. As dataset sizes grow, efficiently selecting optimal subsets for training becomes crucial to balancing performance and computational costs. Traditional data selection methods often require fine-tuning a scoring model on the target dataset (time-consuming and resource-intensive) or rely on heuristics that fail to fully leverage the model's predictive capabilities.

Data Whisperer proposes an **efficient, training-free, attention-based method** that leverages few-shot in-context learning with the model to be fine-tuned.

## Key Results

- Achieves **superior performance compared to the full GSM8K dataset** on Llama-3-8B-Instruct using just **10% of the data**
- Outperforms existing methods with a **3.1-point improvement** and a **7.4× speedup**

## Method

Data Whisperer uses attention-based scoring with the target model itself (via in-context learning) to identify the most informative training samples — no need to train a separate scoring model. This makes it:

- **Training-free:** No additional model training needed for data selection
- **Attention-based:** Uses the model's own attention patterns to assess sample importance
- **Few-shot ICL powered:** Leverages the model's in-context learning ability to evaluate data quality

## Significance for Low-Data Fine-Tuning

This approach is particularly valuable when data is scarce because:
1. It maximizes the value of each training example by selecting the most informative subset
2. Eliminates the overhead of training a data selection model (which itself requires data)
3. The few-shot ICL approach means only a handful of examples are needed to guide selection

## Citation

```bibtex
@inproceedings{wang2025datawhisperer,
  title={Data Whisperer: Efficient Data Selection for Task-Specific LLM Fine-Tuning via Few-Shot In-Context Learning},
  author={Wang, Shaobo and Jin, Xiangqi and Wang, Ziming and Wang, Jize and Zhang, Jiajun and Li, Kaixin and Wen, Zichen and Li, Zhong and He, Conghui and Hu, Xuming and Zhang, Linfeng},
  booktitle={Proceedings of the 63rd Annual Meeting of the Association for Computational Linguistics},
  year={2025}
}
```