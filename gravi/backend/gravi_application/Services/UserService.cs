using gravi_application.Interfaces;
using gravi_infrastructure.Data.UnitOfWork;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.Services
{
    public class UserService : IUserService
    {
        private readonly IUnitOfWorkAsync _unitOfWork;
        private readonly ILogger _logger;

        public UserService(IUnitOfWorkAsync unitOfWork, ILogger<UserService> logger)
        {
            _unitOfWork = unitOfWork;
            _logger = logger;
        }




    }
}
