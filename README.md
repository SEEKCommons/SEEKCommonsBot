Install `wd` via `wikibase-cli`:

```bash
npm install -g wikibase-cli@latest
```

Python modules:

```python
pip install h5py sentence-transformers
```

Create a sample text file:

```bash
cat data/*.txt | shuf -n 100 | steps/view.sh > sample.txt
```

Initialize the database:

```bash
python seek_vectors.py build --in sample.txt --out sample.hdf5
```

Query the database:

```bash
python seek_vectors.py query --h5 sample.hdf5 --text "What is the capital of France?" --top-k 20
```
