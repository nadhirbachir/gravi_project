using gravi_domain.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_infrastructure.Data.UnitOfWork.RepositoryRegisters
{
    public interface IRepositoryRegistry
    {
        IUserRepository User { get; }
        IPersonRepository Person { get; }
        ICountryRepository Country { get; }
    }
}
