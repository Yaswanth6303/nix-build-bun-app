import express from 'express';
import axios from 'axios';

const app = express();
const PORT = 3000;

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/', (_req, res) => {
  return res.status(200).json({
    message: 'Hello, World',
  });
});

async function fetchJsonData() {
  try {
    const response = await axios.get('https://jsonplaceholder.typicode.com/todos/1');
    return response.data;
  } catch (error) {
    console.error('Error fetching JSON data:', error);
    throw error;
  }
}

app.get('/getTodos', async (_req, res) => {
  try {
    res.status(200).json({
      data: await fetchJsonData(),
    });
  } catch (error) {
    res.status(500).json({
      message: 'Internal Server Error',
    });
  }
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
