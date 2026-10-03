# app/models/user_model.py
from app.config.db import get_db  # Import the get_db function
from bson.objectid import ObjectId
import bcrypt
from fastapi import HTTPException

class UserModel:
    @staticmethod
    def get_collection():
        db = get_db()  # Retrieve the current database instance
        return db["users"]

    @staticmethod
    async def create_user(email, password, username, phone):
        try:
            # Hash the password (ensure it's bytes)
            hashed_password = bcrypt.hashpw(password.encode(), bcrypt.gensalt())  # Returns bytes
            user_data = {
                "email": email,
                "password": hashed_password,  # Stored as bytes
                "username": username,
                "phone": phone,
                "likedArticles": []
            }
            collection = UserModel.get_collection()
            result = await collection.insert_one(user_data)
            print(f"DEBUG: User inserted with ID: {result.inserted_id}")  # Debug log
            return result
        except Exception as e:
            print(f"Error creating user: {e}")
            raise HTTPException(status_code=500, detail="Failed to create user")
          
    # @staticmethod
    # async def find_user_by_email(email):
    #     try:
    #         collection = UserModel.get_collection()
    #         user = await collection.find_one({"email": email})
    #         if not user:
    #             raise HTTPException(status_code=404, detail="User not found")
    #         return user
    #     except Exception as e:
    #         print(f"Error finding user by email: {e}")
    #         raise HTTPException(status_code=500, detail="Database error")   
    
    # @staticmethod
    # async def find_user_by_username(username):
    #     try:
    #         collection = UserModel.get_collection()
    #         return await collection.find_one({"username": username})
    #     except Exception as e:
    #         print(f"Error finding user by username: {e}")
    #         raise HTTPException(status_code=500, detail="Database error")

    # @staticmethod
    # async def find_user_by_phone(phone):
    #     try:
    #         collection = UserModel.get_collection()
    #         return await collection.find_one({"phone": phone})
    #     except Exception as e:
    #         print(f"Error finding user by phone: {e}")
    #         raise HTTPException(status_code=500, detail="Database error")

    # Updated find_user_by_email
    @staticmethod
    async def find_user_by_email(email):
        try:
            collection = UserModel.get_collection()
            return await collection.find_one({"email": email})  # Returns None if not found
        except Exception as e:
            print(f"Error finding user by email: {e}")
            raise HTTPException(status_code=500, detail="Database error")

    # Similarly update these methods:
    @staticmethod
    async def find_user_by_username(username):
        try:
            collection = UserModel.get_collection()
            return await collection.find_one({"username": username})
        except Exception as e:
            print(f"Error finding user by username: {e}")
            raise HTTPException(status_code=500, detail="Database error")

    @staticmethod
    async def find_user_by_phone(phone):
        try:
            collection = UserModel.get_collection()
            return await collection.find_one({"phone": phone})
        except Exception as e:
            print(f"Error finding user by phone: {e}")
            raise HTTPException(status_code=500, detail="Database error")
        
    @staticmethod
    async def like_article(email, article_title, article_category):
        try:
            collection = UserModel.get_collection()
            user = await UserModel.find_user_by_email(email)
            if user:
                # Remove ObjectId() conversion - user["_id"] is already an ObjectId
                # Only push if this title isn't already liked, so repeat likes don't create duplicates
                await collection.update_one(
                    {"_id": user["_id"], "likedArticles.title": {"$ne": article_title}},
                    {"$push": {"likedArticles": {"title": article_title, "category": article_category}}}
                )
                return True
            raise HTTPException(status_code=404, detail="User not found")
        except Exception as e:
            print(f"Error liking article: {str(e)}")
            raise HTTPException(status_code=500, detail="Database error")

    @staticmethod
    async def unlike_article(email, article_title):
        try:
            collection = UserModel.get_collection()
            user = await UserModel.find_user_by_email(email)
            if user:
                # Remove ObjectId() here too
                await collection.update_one(
                    {"_id": user["_id"]},  # <-- FIX HERE
                    {"$pull": {"likedArticles": {"title": article_title}}}
                )
                return True
            raise HTTPException(status_code=404, detail="User not found")
        except Exception as e:
            print(f"Error unliking article: {e}")
            raise HTTPException(status_code=500, detail="Database error")