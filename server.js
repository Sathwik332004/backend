const express = require('express');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');
const bodyParser = require('body-parser');
const { classifyTask } = require('./classification'); // Import the logic
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(bodyParser.json());

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

// --- ENDPOINTS ---

app.get('/api/tasks', async (req, res) => {
    const { category, priority, status } = req.query;
    let query = supabase.from('tasks').select('*').order('created_at', { ascending: false });

    if (category) query = query.eq('category', category);
    if (priority) query = query.eq('priority', priority);
    if (status) query = query.eq('status', status);

    const { data, error } = await query;
    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
});

app.get('/api/tasks/:id', async (req, res) => {
    const { id } = req.params;
    const { data, error } = await supabase.from('tasks').select('*').eq('id', id).single();
    if (error) return res.status(404).json({ error: 'Task not found' });
    res.json(data);
});

app.post('/api/tasks', async (req, res) => {
    const { title, description, assigned_to, due_date } = req.body;
    if (!title) return res.status(400).json({ error: 'Title is required' });

    // USE IMPORTED LOGIC HERE
    const classification = classifyTask(title, description || '');

    const newTask = {
        title,
        description,
        assigned_to,
        due_date,
        status: 'pending',
        category: classification.category,
        priority: classification.priority,
        extracted_entities: classification.extracted_entities,
        suggested_actions: classification.suggested_actions
    };

    const { data, error } = await supabase.from('tasks').insert([newTask]).select();

    if (error) return res.status(500).json({ error: error.message });

    await supabase.from('task_history').insert([{
        task_id: data[0].id,
        action: 'created',
        new_value: data[0]
    }]);

    res.status(201).json(data[0]);
});

app.patch('/api/tasks/:id', async (req, res) => {
    const { id } = req.params;
    const updates = req.body;
    updates.updated_at = new Date();

    const { data: oldData } = await supabase.from('tasks').select('*').eq('id', id).single();
    const { data, error } = await supabase.from('tasks').update(updates).eq('id', id).select();

    if (error) return res.status(500).json({ error: error.message });

    if (oldData) {
        await supabase.from('task_history').insert([{
            task_id: id,
            action: 'updated',
            old_value: oldData,
            new_value: data[0]
        }]);
    }

    res.json(data[0]);
});

app.delete('/api/tasks/:id', async (req, res) => {
    const { id } = req.params;
    const { error } = await supabase.from('tasks').delete().eq('id', id);
    if (error) return res.status(500).json({ error: error.message });
    res.json({ message: 'Task deleted' });
});

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});