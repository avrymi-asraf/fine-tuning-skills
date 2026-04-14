---
title: "Prompt Engineering"
author: "Lilian Weng"
url: "https://lilianweng.github.io/posts/2023-03-15-prompt-engineering/"
fetched_at: "2026-04-13"
type: blog-post
---

# Prompt Engineering

*Lilian Weng, March 2023*

Prompt Engineering, also known as In-Context Prompting, refers to methods for how to communicate with LLM to steer its behavior for desired outcomes without updating the model weights. It is an empirical science and the effect of prompt engineering methods can vary a lot among models, thus requiring heavy experimentation and heuristics.

This post only focuses on prompt engineering for autoregressive language models, so nothing with Cloze tests, image generation or multimodality models. At its core, the goal of prompt engineering is about alignment and model steerability.

## Basic Prompting

### Zero-Shot
Zero-shot learning is to simply feed the task text to the model and ask for results.

### Few-Shot
Few-shot learning presents a set of high-quality demonstrations, each consisting of both input and desired output, on the target task.

**Tips for Example Selection:**
- Choose examples that are semantically similar to the test example using k-NN clustering in the embedding space (Liu et al., 2021)
- Use a graph-based approach for diverse and representative selection (Su et al., 2022)
- Train embeddings via contrastive learning for in-context learning sample selection (Rubin et al., 2022)
- Use Q-Learning for sample selection (Zhang et al. 2022)
- Use uncertainty-based active learning to identify high-disagreement examples (Diao et al., 2023)

**Tips for Example Ordering:**
- Keep selection diverse, relevant, and in random order to avoid majority label bias and recency bias
- Increasing model sizes or including more training examples does not reduce variance among permutations

## Instruction Prompting

Instructed LM finetunes a pretrained model with high-quality tuples of (task instruction, input, ground truth output) to make LM better understand user intention. RLHF is a common method.

In-context instruction learning (Ye et al. 2023) combines few-shot learning with instruction prompting.

## Self-Consistency Sampling

Sample multiple outputs with temperature > 0 and then select the best one. A general solution is majority vote.

## Chain-of-Thought (CoT)

CoT prompting generates reasoning chains step by step to lead to the final answer. Benefit is more pronounced for complicated reasoning tasks with large models (>50B parameters).

### Types of CoT Prompts
- **Few-shot CoT:** Prompt with demonstrations containing reasoning chains
- **Zero-shot CoT:** Use "Let's think step by step" to encourage reasoning (Kojima et al. 2022)

### Tips and Extensions
- Self-consistency sampling improves reasoning accuracy via majority vote
- STaR method: generate reasoning chains, keep those leading to correct answers, fine-tune
- Prompts with higher reasoning complexity achieve better performance
- Self-Ask: iteratively prompt model to ask follow-up questions
- Tree of Thoughts: explores multiple reasoning possibilities at each step

## Automatic Prompt Design

- **APE (Automatic Prompt Engineer):** Search over model-generated instruction candidates and filter by score function
- **Augment-Prune-Select:** Generate pseudo-chains, prune incorrect ones, learn probability distribution
- **Clustering approach:** Embed questions, cluster with k-means, select representative from each cluster

## Augmented Language Models

### Retrieval
Use search/retrieval over knowledge base and incorporate retrieved content as part of the prompt.

### Programming Language
- **PAL (Program-aided language models):** Ask LLM to generate programming statements to resolve reasoning problems
- **PoT (Program of Thoughts):** Similar approach offloading computation to Python interpreter

### External APIs
- **TALM:** Text-to-text API calls with self-play bootstrapping
- **Toolformer:** Self-supervised tool use with simple APIs (calculator, Q&A, search, translation, calendar)

---

*Full article: https://lilianweng.github.io/posts/2023-03-15-prompt-engineering/*