from flask import request, jsonify


class APIController:
    def __init__(self, app, repository, calculator, backlog_monitor=None):
        self.app = app
        self.repo = repository
        self.calc = calculator
        self.backlog = backlog_monitor
        self._setup()

    def _setup(self):
        @self.app.route('/health', methods=['GET'])
        def health():
            return jsonify({"status": "ok"}), 200

        @self.app.route('/record', methods=['POST'])
        def record():
            payload = request.json
            if payload:
                self.repo.save(payload)
            return jsonify({"status": "ok"}), 200

        @self.app.route('/stats', methods=['GET'])
        def stats():
            return jsonify(self.calc.calculate()), 200

        @self.app.route('/backlog', methods=['GET'])
        def backlog():
            if self.backlog is None:
                return jsonify({"error": "backlog monitor disabled"}), 503
            return jsonify(self.backlog.lag()), 200

        @self.app.route('/reset', methods=['POST'])
        def reset():
            self.repo.reset()
            return jsonify({"status": "reset"}), 200

        @self.app.route('/raw', methods=['GET'])
        def raw():
            limit = int(request.args.get('limit', '100'))
            events = self.repo.all()
            return jsonify(events[-limit:]), 200
