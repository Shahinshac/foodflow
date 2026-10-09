from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import User, Expense, Category, TransactionType
from ..schemas import (
    ExpenseCreate, ExpenseResponse, CategoryResponse, CategoryCreate,
    ExpenseSummaryResponse, CategorySummary
)
from ..auth import get_current_user

router = APIRouter(prefix="/expenses", tags=["Expenses"])

@router.get("/categories", response_model=List[CategoryResponse])
def get_categories(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Category).filter(
        (Category.user_id == None) | (Category.user_id == current_user.id)
    ).all()

@router.post("/categories", response_model=CategoryResponse)
def create_category(
    cat_in: CategoryCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    category = Category(
        user_id=current_user.id,
        name=cat_in.name,
        icon=cat_in.icon,
        color_hex=cat_in.color_hex,
        type=cat_in.type
    )
    db.add(category)
    db.commit()
    db.refresh(category)
    return category

@router.get("", response_model=List[ExpenseResponse])
def get_expenses(
    category_id: Optional[int] = None,
    type: Optional[TransactionType] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    q = db.query(Expense).filter(Expense.user_id == current_user.id)
    if category_id:
        q = q.filter(Expense.category_id == category_id)
    if type:
        q = q.filter(Expense.type == type)
    return q.order_by(Expense.date.desc()).all()

@router.post("", response_model=ExpenseResponse)
def create_expense(
    exp_in: ExpenseCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    category = db.query(Category).filter(Category.id == exp_in.category_id).first()
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")

    expense = Expense(
        user_id=current_user.id,
        category_id=exp_in.category_id,
        title=exp_in.title,
        amount_paise=exp_in.amount_paise,
        type=exp_in.type,
        notes=exp_in.notes,
        date=exp_in.date or datetime.utcnow()
    )
    db.add(expense)
    db.commit()
    db.refresh(expense)
    return expense

@router.delete("/{expense_id}")
def delete_expense(
    expense_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    expense = db.query(Expense).filter(
        Expense.id == expense_id,
        Expense.user_id == current_user.id
    ).first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    db.delete(expense)
    db.commit()
    return {"message": "Expense deleted successfully"}

@router.get("/summary", response_model=ExpenseSummaryResponse)
def get_summary(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    expenses = db.query(Expense).filter(Expense.user_id == current_user.id).all()

    total_income = sum(e.amount_paise for e in expenses if e.type == TransactionType.INCOME)
    total_expense = sum(e.amount_paise for e in expenses if e.type == TransactionType.EXPENSE)
    net_balance = total_income - total_expense

    # Category breakdown for expenses
    cat_totals = {}
    expense_items = [e for e in expenses if e.type == TransactionType.EXPENSE]

    for e in expense_items:
        cat_id = e.category_id
        if cat_id not in cat_totals:
            cat_totals[cat_id] = {
                "category": e.category,
                "amount": 0
            }
        cat_totals[cat_id]["amount"] += e.amount_paise

    cat_summaries = []
    for cat_id, data in cat_totals.items():
        cat = data["category"]
        amount = data["amount"]
        pct = (amount / total_expense * 100) if total_expense > 0 else 0.0
        cat_summaries.append(CategorySummary(
            category_id=cat.id,
            category_name=cat.name,
            color_hex=cat.color_hex,
            icon=cat.icon,
            total_amount_paise=amount,
            percentage=round(pct, 1)
        ))

    cat_summaries.sort(key=lambda x: x.total_amount_paise, reverse=True)

    return ExpenseSummaryResponse(
        total_income_paise=total_income,
        total_expense_paise=total_expense,
        net_balance_paise=net_balance,
        category_summaries=cat_summaries
    )
