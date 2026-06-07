-- Migration: Add expenses table for expense management
-- This allows tracking business expenses and calculating net profit

-- Create expenses table
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  expense_date DATE NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('Electricity', 'Water', 'Salary', 'Rent', 'Raw Materials', 'Transportation', 'Marketing', 'Other')),
  description TEXT NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

-- Create policies for expenses
-- Users can read all expenses (for reporting)
CREATE POLICY "Users can view all expenses"
  ON expenses FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
    )
  );

-- Admins can insert expenses
CREATE POLICY "Admins can insert expenses"
  ON expenses FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admins can update expenses
CREATE POLICY "Admins can update expenses"
  ON expenses FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admins can delete expenses
CREATE POLICY "Admins can delete expenses"
  ON expenses FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_expenses_expense_date ON expenses(expense_date);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);
CREATE INDEX IF NOT EXISTS idx_expenses_created_by ON expenses(created_by);

-- Verification query
SELECT 
  id, 
  expense_date, 
  category, 
  description, 
  amount, 
  created_by, 
  created_at 
FROM expenses 
ORDER BY expense_date DESC;
