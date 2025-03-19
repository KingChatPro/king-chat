from flask import Flask, render_template, request, redirect, url_for, session, flash
from flask_socketio import SocketIO, send
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
import os

# إنشاء تطبيق Flask
app = Flask(__name__)
app.config['SECRET_KEY'] = os.urandom(24)

# إعداد قاعدة البيانات (SQLite)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///database/chat.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# إعداد SocketIO للمراسلة الفورية
socketio = SocketIO(app)

# إعداد LoginManager
login_manager = LoginManager(app)
login_manager.login_view = 'login'

# نموذج المستخدم
class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(100), unique=True, nullable=False)
    password = db.Column(db.String(100), nullable=False)

# إنشاء قاعدة البيانات إذا لم تكن موجودة
with app.app_context():
    db.create_all()

# الصفحة الرئيسية
@app.route('/')
@login_required
def index():
    return render_template('index.html', username=current_user.username)

# صفحة التسجيل
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        if User.query.filter_by(username=username).first():
            flash('اسم المستخدم موجود بالفعل!', 'danger')
            return redirect(url_for('register'))

        new_user = User(username=username, password=password)
        db.session.add(new_user)
        db.session.commit()
        login_user(new_user)
        return redirect(url_for('index'))

    return render_template('register.html')

# صفحة تسجيل الدخول
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        user = User.query.filter_by(username=username).first()

        if user and user.password == password:
            login_user(user)
            return redirect(url_for('index'))
        else:
            flash('بيانات الدخول غير صحيحة', 'danger')

    return render_template('login.html')

# تسجيل الخروج
@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login'))

# معالجة الرسائل الفورية
@socketio.on('message')
def handle_message(msg):
    send(msg, broadcast=True)

# إعداد الجلسات للمستخدمين
@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# تشغيل التطبيق
if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)
